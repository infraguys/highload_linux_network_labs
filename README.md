# Workshop about Linux-based software networking and containers

## Feedback, questions, etc

Feel free to ask anything:
- [Telegram chat t.me/hl_network_workshop](https://t.me/hl_network_workshop)
- [Github discussions](https://github.com/infraguys/highload_linux_network_labs/discussions)
- Open Issues if you have a problem with scripts

## Useful materials:
- [cheat sheet](https://drive.google.com/file/d/1xXYeR9KwdBGP9ZKmhfIqDoeyB74StqvN/view?usp=sharing)
- [presentation](https://drive.google.com/file/d/1BfbjA_RuW7dn45HW3b7GYfSe9tbeq1nD/view?usp=sharing)

## Labs:
- [lab0](./labs/lab0_test.sh): routing, **test lab without any problems**
- [lab1](./labs/lab1.sh): basic network with namespaces
- [lab2](./labs/lab2.sh): routing
- [lab3](./labs/lab3.sh): bridges
- [lab4](./labs/lab4.sh): container's network namespace
- [lab5](./labs/lab5.sh): Open vSwitch basic flows (*extra credit lab*)

## How to run it on local machine

> **_NOTE:_**  It should not be dangerous to run it on personal system (most things are not persistent and reboot should drop them),
> BUT IT IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND! Please open an issue if you have found a problem!

- **Tested on Debian 12 only**, but it's recommended to use VMs provided by speakers
- Install packages: `apt install docker.io openvswitch-switch`
  - you may use docker from other source (for ex. docker official repo)
- Clone this repo: `git clone https://github.com/infraguys/highload_linux_network_labs.git`
- `cd ./highload_linux_network_labs/labs`
- you're ready to go!


## Motivation

Linux network stack is a beast of its own and may have a large complexity inside,
BUT we believe that common functionality is pretty simple.

That's why we've prepared some tasks which can help you to gain basic experience
via debugging of easy-to-introduce problems.
