package com.nexiosit.choretracker

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication

@SpringBootApplication
class ChoreTrackerApiApplication

fun main(args: Array<String>) {
	runApplication<ChoreTrackerApiApplication>(*args)
}
