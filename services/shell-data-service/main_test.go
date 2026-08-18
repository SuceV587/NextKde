package main

import (
	"bufio"
	"net"
	"os"
	"path/filepath"
	"testing"
)

func TestDesktopSubscriptionImmediatelyAnnouncesSnapshot(t *testing.T) {
	service := &Service{desktopSubscribers: map[net.Conn]struct{}{}}
	server, client := net.Pipe()
	defer server.Close()
	defer client.Close()

	done := make(chan struct{})
	go func() {
		service.subscribeDesktop(server)
		close(done)
	}()
	line, err := bufio.NewReader(client).ReadString('\n')
	if err != nil {
		t.Fatal(err)
	}
	if line != "desktop_changed\n" {
		t.Fatalf("unexpected initial notification %q", line)
	}
	<-done
}

func TestRefreshDesktopReconcilesCompleteDirectory(t *testing.T) {
	directory := t.TempDir()
	service := &Service{desktopDirectory: directory}

	if !service.refreshDesktop() {
		t.Fatal("initial directory state was not accepted")
	}
	if service.refreshDesktop() {
		t.Fatal("unchanged directory produced a false update")
	}
	path := filepath.Join(directory, "first.txt")
	if err := os.WriteFile(path, []byte("first"), 0600); err != nil {
		t.Fatal(err)
	}
	if !service.refreshDesktop() {
		t.Fatal("new file was not found by complete reconciliation")
	}
	if len(service.state.Desktop.Entries) != 1 ||
		service.state.Desktop.Entries[0].Path != path {
		t.Fatalf("unexpected desktop snapshot: %#v", service.state.Desktop.Entries)
	}
}

func TestNormalizeClipboardPaths(t *testing.T) {
	paths := normalizeClipboardPaths([]string{
		"relative", "/tmp/a", "/tmp/a/../a", "/tmp/b",
	})
	if len(paths) != 2 || paths[0] != "/tmp/a" || paths[1] != "/tmp/b" {
		t.Fatalf("unexpected paths: %#v", paths)
	}
}
