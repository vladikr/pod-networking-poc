package main

import (
	"fmt"
	"os"
	"sync"
	"syscall"

	"./network"
)

func main() {
	var wg sync.WaitGroup
	wg.Add(1)

	mac, err := network.SetupDefaultPodNetwork()
	if err != nil {
		panic(err)
	}
	env := os.Environ()
	sub := fmt.Sprintf("s/MYMAC/%s/g", mac.String())
	args := []string{"sed", "-i", sub, "testvm.xml"}
	execErr := syscall.Exec("/usr/bin/sed", args, env)
	if execErr != nil {
		panic(execErr)
	}
	wg.Wait()
}
