/*
 * pneumatic_hub.cpp
 *
 * Created: 06/05/2024 19:02:01
 * Author : micro
 */ 

#include "board.h"
#include "reactor.h"
#include "pressure_mon.h"
#include "protocol.h"
#include "i2c_slave.h"


int main(void)
{
   // Initialise the board hardware (clocks, IOs, buses etc.)
   board_init();

   // Start measuring the input with filter
   pressure_mon_init();
   
   // The protocol is time sensitive - get it started
   protocol_init();
   
   // Turn on this board as an i2c slave
   i2c_slave_init();
   
   // Ready the reactor
   reactor_init();
   
   // Off we go!
   reactor_run();
}

