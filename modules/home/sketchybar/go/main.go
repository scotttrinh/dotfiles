package main

import (
	"fmt"
	"os"
)

func helpText() string {
	return "usage: sketchybar-plugins [command]"
}

func main() {
	if len(os.Args) != 2 {
		fmt.Fprintln(os.Stderr, helpText())
		os.Exit(2)
	}

	var err error
	var output string
	name := os.Getenv("NAME")

	switch os.Args[1] {
	case "probe":
		output, err = runProbe(name)
	case "clock":
		output, err = runClock(name)
	default:
		fmt.Fprintln(os.Stderr, helpText())
		os.Exit(2)
	}

	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	if output != "" {
		fmt.Println(output)
	}
}
