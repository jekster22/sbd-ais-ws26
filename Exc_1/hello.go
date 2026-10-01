package main

import "fmt"

type Greeting struct {
	Text string
}

func (g Greeting) Print() {
	fmt.Println(g.Text)
}

func main() {
	hello := Greeting{
		Text: "Hello, World!",
	}

	hello.Print()
}
