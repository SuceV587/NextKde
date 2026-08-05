// shell-data-service owns persistent shell telemetry. It deliberately has no
// GUI dependencies: Quickshell only consumes snapshot.json.
package main

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/fsnotify/fsnotify"
)

type MetricSample struct {
	At                                                         int64   `json:"at"`
	CPU, Memory, Disk, Frequency, AverageMilliC, MaximumMilliC float64 `json:",omitempty"`
}
type Metrics struct {
	CPU, Memory, Disk                          float64        `json:"cpu,memory,disk"`
	FrequencyMHz, AverageMilliC, MaximumMilliC float64        `json:"frequencyMhz,averageMilliC,maximumMilliC"`
	History                                    []MetricSample `json:"history"`
}
type AppUsage struct {
	Name, Icon string  `json:"name,omitempty"`
	Seconds    float64 `json:"seconds"`
}
type Activity struct {
	Active      bool                `json:"active"`
	ActiveApp   string              `json:"activeApp,omitempty"`
	TodayApps   map[string]AppUsage `json:"todayApps"`
	UptimeByDay map[string]float64  `json:"uptimeByDay"`
}
type DesktopEntry struct {
	Name       string `json:"name"`
	Title      string `json:"title,omitempty"`
	Path       string `json:"path"`
	Kind       string `json:"kind"`
	Icon       string `json:"icon,omitempty"`
	ModifiedAt int64  `json:"modifiedAt"`
}
type Desktop struct {
	Directory string         `json:"directory"`
	Entries   []DesktopEntry `json:"entries"`
	UpdatedAt int64          `json:"updatedAt"`
}
type Snapshot struct {
	GeneratedAt int64    `json:"generatedAt"`
	Metrics     Metrics  `json:"metrics"`
	Activity    Activity `json:"activity"`
	Desktop     Desktop  `json:"desktop"`
}
type State struct {
	Metrics  Metrics  `json:"metrics"`
	Activity Activity `json:"activity"`
	Desktop  Desktop  `json:"desktop"`
}
type Event struct {
	Type, AppID, Name, Icon string `json:"type,omitempty"`
	Active                  *bool  `json:"active,omitempty"`
}

type Service struct {
	mu                      sync.Mutex
	desktopSubscribersMu    sync.Mutex
	desktopSubscribers      map[net.Conn]struct{}
	state                   State
	statePath, snapshotPath string
	last                    time.Time
}

func day(t time.Time) string { return t.Format("2006-01-02") }
func homePath(env, fallback string) string {
	if v := os.Getenv(env); v != "" {
		return v
	}
	return fallback
}

func newService() *Service {
	home, _ := os.UserHomeDir()
	stateRoot := homePath("XDG_STATE_HOME", filepath.Join(home, ".local", "state"))
	root := filepath.Join(stateRoot, "quickshell", "shell-data-service")
	s := &Service{
		statePath:          filepath.Join(root, "state.json"),
		snapshotPath:       filepath.Join(root, "snapshot.json"),
		desktopSubscribers: map[net.Conn]struct{}{},
		last:               time.Now(),
	}
	s.state.Activity.TodayApps = map[string]AppUsage{}
	s.state.Activity.UptimeByDay = map[string]float64{}
	if raw, err := os.ReadFile(s.statePath); err == nil {
		_ = json.Unmarshal(raw, &s.state)
	}
	if s.state.Activity.TodayApps == nil {
		s.state.Activity.TodayApps = map[string]AppUsage{}
	}
	if s.state.Activity.UptimeByDay == nil {
		s.state.Activity.UptimeByDay = map[string]float64{}
	}
	return s
}

func writeJSON(path string, value any) error {
	raw, err := json.Marshal(value)
	if err != nil {
		return err
	}
	if err = os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err = os.WriteFile(tmp, raw, 0644); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}
func (s *Service) settle(now time.Time) {
	seconds := now.Sub(s.last).Seconds()
	if seconds > 0 && seconds < 120 {
		s.state.Activity.UptimeByDay[day(s.last)] += seconds
		if s.state.Activity.Active && s.state.Activity.ActiveApp != "" {
			app := s.state.Activity.TodayApps[s.state.Activity.ActiveApp]
			app.Seconds += seconds
			s.state.Activity.TodayApps[s.state.Activity.ActiveApp] = app
		}
	}
	s.last = now
}
func (s *Service) persist() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.settle(time.Now())
	snapshot := Snapshot{GeneratedAt: time.Now().UnixMilli(), Metrics: s.state.Metrics, Activity: s.state.Activity, Desktop: s.state.Desktop}
	_ = writeJSON(s.statePath, s.state)
	_ = writeJSON(s.snapshotPath, snapshot)
}

// subscribeDesktop turns the existing local event socket into a small
// notification channel as well. QML keeps one connection open and only reads
// the snapshot after a change notification, so neither side polls a directory.
func (s *Service) subscribeDesktop(conn net.Conn) {
	s.desktopSubscribersMu.Lock()
	s.desktopSubscribers[conn] = struct{}{}
	s.desktopSubscribersMu.Unlock()
}

func (s *Service) unsubscribeDesktop(conn net.Conn) {
	s.desktopSubscribersMu.Lock()
	delete(s.desktopSubscribers, conn)
	s.desktopSubscribersMu.Unlock()
}

func (s *Service) publishDesktop() {
	s.desktopSubscribersMu.Lock()
	defer s.desktopSubscribersMu.Unlock()
	for conn := range s.desktopSubscribers {
		_ = conn.SetWriteDeadline(time.Now().Add(100 * time.Millisecond))
		if _, err := conn.Write([]byte("desktop_changed\n")); err != nil {
			delete(s.desktopSubscribers, conn)
			_ = conn.Close()
		}
	}
}

func desktopDirectory() string {
	if output, err := exec.Command("xdg-user-dir", "DESKTOP").Output(); err == nil {
		if directory := strings.TrimSpace(string(output)); directory != "" {
			return directory
		}
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, "Desktop")
}

func desktopKind(entry os.DirEntry) string {
	if entry.IsDir() {
		return "folder"
	}
	extension := strings.ToLower(filepath.Ext(entry.Name()))
	switch extension {
	case ".desktop":
		return "launcher"
	case ".png", ".jpg", ".jpeg", ".webp", ".gif", ".svg":
		return "image"
	case ".pdf":
		return "pdf"
	case ".md", ".txt", ".rst":
		return "text"
	case ".py", ".go", ".js", ".ts", ".qml", ".sh", ".json", ".yaml", ".yml":
		return "code"
	default:
		return "file"
	}
}

func desktopLauncherPresentation(path string) (string, string) {
	file, err := os.Open(path)
	if err != nil {
		return "", ""
	}
	defer file.Close()

	inEntry := false
	name, icon := "", ""
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "[Desktop Entry]" {
			inEntry = true
			continue
		}
		if inEntry && strings.HasPrefix(line, "[") {
			break
		}
		if !inEntry || strings.HasPrefix(line, "#") {
			continue
		}
		key, value, found := strings.Cut(line, "=")
		if !found {
			continue
		}
		switch key {
		case "Name":
			name = strings.TrimSpace(value)
		case "Icon":
			icon = strings.TrimSpace(value)
		}
	}
	return name, icon
}

func readDesktop() Desktop {
	directory := desktopDirectory()
	desktop := Desktop{Directory: directory, Entries: []DesktopEntry{}}
	entries, err := os.ReadDir(directory)
	if err != nil {
		return desktop
	}
	for _, entry := range entries {
		// Match standard desktop behaviour: dot-files are managed by their
		// owning applications and do not appear as desktop icons by default.
		if strings.HasPrefix(entry.Name(), ".") {
			continue
		}
		info, err := entry.Info()
		if err != nil {
			continue
		}
		kind := desktopKind(entry)
		title, icon := "", ""
		if kind == "launcher" {
			title, icon = desktopLauncherPresentation(filepath.Join(directory, entry.Name()))
		}
		desktop.Entries = append(desktop.Entries, DesktopEntry{
			Name: entry.Name(), Path: filepath.Join(directory, entry.Name()),
			Title: title, Kind: kind, Icon: icon, ModifiedAt: info.ModTime().UnixMilli(),
		})
	}
	sort.SliceStable(desktop.Entries, func(left, right int) bool {
		leftFolder := desktop.Entries[left].Kind == "folder"
		rightFolder := desktop.Entries[right].Kind == "folder"
		if leftFolder != rightFolder {
			return leftFolder
		}
		if desktop.Entries[left].ModifiedAt != desktop.Entries[right].ModifiedAt {
			return desktop.Entries[left].ModifiedAt > desktop.Entries[right].ModifiedAt
		}
		return strings.ToLower(desktop.Entries[left].Name) < strings.ToLower(desktop.Entries[right].Name)
	})
	desktop.UpdatedAt = time.Now().UnixMilli()
	return desktop
}

func (s *Service) refreshDesktop() bool {
	desktop := readDesktop()
	s.mu.Lock()
	defer s.mu.Unlock()
	previous := s.state.Desktop
	// The update time is intentionally excluded: unchanged directory scans do
	// not churn the atomic snapshot or wake the QML consumer.
	previous.UpdatedAt = 0
	comparison := desktop
	comparison.UpdatedAt = 0
	if reflect.DeepEqual(previous, comparison) {
		return false
	}
	s.state.Desktop = desktop
	return true
}

// watchDesktop is the primary source of desktop-file updates. Event bursts
// from editors, sync clients, and atomic replaces become one snapshot write.
func watchDesktop(s *Service) {
	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		fmt.Fprintln(os.Stderr, "desktop watcher:", err)
		return
	}
	defer watcher.Close()
	if err := watcher.Add(desktopDirectory()); err != nil {
		fmt.Fprintln(os.Stderr, "desktop watcher add:", err)
		return
	}

	const debounce = 120 * time.Millisecond
	var timer *time.Timer
	var timerC <-chan time.Time
	scheduleRefresh := func() {
		if timer == nil {
			timer = time.NewTimer(debounce)
			timerC = timer.C
			return
		}
		if !timer.Stop() {
			select {
			case <-timer.C:
			default:
			}
		}
		timer.Reset(debounce)
		// timerC is cleared after every delivery. Reattach it here so every
		// subsequent filesystem burst, not just the first one, reaches select.
		timerC = timer.C
	}
	for {
		select {
		case event, ok := <-watcher.Events:
			if !ok {
				return
			}
			if event.Op&(fsnotify.Create|fsnotify.Remove|fsnotify.Rename|fsnotify.Write) != 0 {
				scheduleRefresh()
			}
		case err, ok := <-watcher.Errors:
			if !ok {
				return
			}
			fmt.Fprintln(os.Stderr, "desktop watcher event:", err)
			scheduleRefresh()
		case <-timerC:
			timerC = nil
			if s.refreshDesktop() {
				s.persist()
				s.publishDesktop()
			}
		}
	}
}

func readCPU() float64 {
	raw, err := os.ReadFile("/proc/stat")
	if err != nil {
		return 0
	}
	fields := strings.Fields(strings.SplitN(string(raw), "\n", 2)[0])
	if len(fields) < 6 {
		return 0
	}
	total, idle := float64(0), float64(0)
	for i := 1; i < len(fields); i++ {
		n, _ := strconv.ParseFloat(fields[i], 64)
		total += n
		if i == 4 || i == 5 {
			idle += n
		}
	}
	_ = total
	_ = idle
	return 0
}
func readMem() float64 {
	raw, err := os.ReadFile("/proc/meminfo")
	if err != nil {
		return 0
	}
	total, avail := float64(0), float64(0)
	for _, l := range strings.Split(string(raw), "\n") {
		f := strings.Fields(l)
		if len(f) < 2 {
			continue
		}
		v, _ := strconv.ParseFloat(f[1], 64)
		if f[0] == "MemTotal:" {
			total = v
		}
		if f[0] == "MemAvailable:" {
			avail = v
		}
	}
	if total == 0 {
		return 0
	}
	return 1 - avail/total
}
func readTemp() (float64, float64) {
	entries, _ := filepath.Glob("/sys/class/thermal/thermal_zone*/temp")
	sum, max := float64(0), float64(0)
	for _, p := range entries {
		raw, e := os.ReadFile(p)
		if e != nil {
			continue
		}
		v, _ := strconv.ParseFloat(strings.TrimSpace(string(raw)), 64)
		if v > 0 {
			sum += v
			if v > max {
				max = v
			}
		}
	}
	if max == 0 {
		return -1, -1
	}
	return sum / float64(len(entries)), max
}
func (s *Service) sample() {
	s.mu.Lock()
	defer s.mu.Unlock()
	avg, max := readTemp()
	s.state.Metrics.AverageMilliC = avg
	s.state.Metrics.MaximumMilliC = max
	s.state.Metrics.Memory = readMem()
	sample := MetricSample{At: time.Now().UnixMilli(), Memory: s.state.Metrics.Memory, AverageMilliC: avg, MaximumMilliC: max}
	s.state.Metrics.History = append(s.state.Metrics.History, sample)
	if len(s.state.Metrics.History) > 360 {
		s.state.Metrics.History = s.state.Metrics.History[len(s.state.Metrics.History)-360:]
	}
}
func (s *Service) event(e Event) {
	// Desktop mutations originate from the shell itself as well as external
	// file managers.  Shell-originated mutations request this immediate scan so
	// the UI does not have to wait for the low-frequency safety poll below.
	if e.Type == "refresh_desktop" {
		if s.refreshDesktop() {
			s.persist()
			s.publishDesktop()
		}
		return
	}
	s.mu.Lock()
	s.settle(time.Now())
	switch e.Type {
	case "active_app":
		s.state.Activity.ActiveApp = e.AppID
		s.state.Activity.Active = e.AppID != ""
		app := s.state.Activity.TodayApps[e.AppID]
		app.Name = e.Name
		if e.Icon != "" {
			app.Icon = e.Icon
		}
		s.state.Activity.TodayApps[e.AppID] = app
	case "session":
		if e.Active != nil {
			s.state.Activity.Active = *e.Active
		}
	}
	s.mu.Unlock()
}
func serve(s *Service, path string) error {
	_ = os.Remove(path)
	l, err := net.Listen("unix", path)
	if err != nil {
		return err
	}
	defer l.Close()
	for {
		c, e := l.Accept()
		if e != nil {
			return e
		}
		go func() {
			defer c.Close()
			// Every local socket connection can receive a desktop notification.
			// One-shot event senders close immediately; the QML reader keeps its
			// connection open. This avoids a timing-sensitive subscribe write at
			// process startup while retaining the same lightweight protocol.
			s.subscribeDesktop(c)
			defer s.unsubscribeDesktop(c)
			scanner := bufio.NewScanner(c)
			for scanner.Scan() {
				var event Event
				if json.Unmarshal(scanner.Bytes(), &event) != nil {
					continue
				}
				s.event(event)
			}
		}()
	}
}

func main() {
	s := newService()
	runtime := homePath("XDG_RUNTIME_DIR", "/tmp")
	socket := filepath.Join(runtime, "shell-data-service.sock")
	go func() {
		if err := serve(s, socket); err != nil && !errors.Is(err, net.ErrClosed) {
			fmt.Fprintln(os.Stderr, err)
		}
	}()
	tick := time.NewTicker(10 * time.Second)
	save := time.NewTicker(60 * time.Second)
	defer tick.Stop()
	defer save.Stop()
	s.sample()
	s.refreshDesktop()
	s.persist()
	go watchDesktop(s)
	for {
		select {
		case <-tick.C:
			s.sample()
		case <-save.C:
			s.persist()
		}
	}
}
