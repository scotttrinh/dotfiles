package main

import (
	"testing"
	"time"
)

func TestFormatInterval(t *testing.T) {
	tests := []struct {
		name string
		in   time.Duration
		want string
	}{
		{name: "rounds minutes", in: 90 * time.Second, want: "2 minutes"},
		{name: "singular", in: 60 * time.Second, want: "1 minute"},
		{name: "less than minute", in: 10 * time.Second, want: "1 minute"},
		{name: "at one hour", in: time.Hour, want: "1h"},
		{name: "boundary", in: 89 * time.Minute, want: "1h"},
		{name: "boundary exceeded", in: 90 * time.Minute, want: "2h"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := formatInterval(tt.in); got != tt.want {
				t.Errorf("formatInterval(%q) = %q, want %q", tt.in, got, tt.want)
			}
		})
	}
}

func FuzzIntervalMinuteProgression(f *testing.F) {
	f.Add(uint64(90))

	f.Fuzz(func(t *testing.T, n uint64) {
		seconds := 30 + n%3500
		d := time.Duration(seconds) * time.Second

		got := formatInterval(d)
		next := formatInterval(d + time.Minute)
		if got == next {
			t.Fatalf("formatInterval returned the same time when adding a minute, got=%s, next=%s, d=%s", got, next, d)
		}
	})
}
