package main

import (
	"fmt"
	"os"
	"os/exec"
	"time"
)

func formatClock(t time.Time) string {
	shortWeekday := t.Format("Mon")[:2]
	return fmt.Sprintf("%s %s", shortWeekday, t.Format("1/2 3:04 PM"))
}

func formatInterval(d time.Duration) string {
	if d >= time.Hour {
		hours := int((d + 30*time.Minute) / time.Hour)
		return fmt.Sprintf("%dh", hours)
	}
	unit := "minutes"
	minutes := max(1, int((d+30*time.Second)/time.Minute))
	if minutes == 1 {
		unit = "minute"
	}
	return fmt.Sprintf("%d %s", minutes, unit)
}

func runClock(name string) (string, error) {
	output := formatClock(time.Now())
	if name == "" {
		return output, nil
	}

	command := exec.Command("sketchybar", "--set", "clock", "label="+output)
	command.Stdout = os.Stdout
	command.Stderr = os.Stderr
	return "", command.Run()
}
