package main

import (
	"os"
	"os/exec"
)

func runProbe(name string) (string, error) {
	var output string
	if name == "" {
		output = "Go plugin ready"
		return output, nil
	}
	output = "Go works"

	command := exec.Command("sketchybar", "--set", name, "label="+output)
	command.Stdout = os.Stdout
	command.Stderr = os.Stderr
	return "", command.Run()
}
