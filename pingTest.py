from TestSim import TestSim

def main():
    # Get simulation ready to run.
    s = TestSim();

    # Before we do anything, lets simulate the network off.
    s.runTime(1);

    # Load the the layout of the network.
    s.loadTopo("long_line.topo");

    # Add a noise model to all of the motes.
    s.loadNoise("no_noise.txt");

    # Turn on all of the sensors.
    s.bootAll();

    # Add the main channels. These channels are declared in includes/channels.h
    s.addChannel(s.COMMAND_CHANNEL);
    s.addChannel(s.GENERAL_CHANNEL);
    s.addChannel(s.NEIGHBOR_CHANNEL); # Added channel to the simulation
    s.addChannel(s.FLOODING_CHANNEL);
    s.addChannel(s.ROUTING_CHANNEL);
    s.addChannel(s.TRANSPORT_CHANNEL);

    # After sending a ping, simulate a little to prevent collision.

    # ***IMPORTANT*** - change TABLE_SIZE according to the number of nodes when using routing
    s.runTime(100);
    s.testServer(1, 10);
    # s.routeDMP(9);
    s.runTime(100);
    s.testServer(1, 11);
    # s.testClient(3, 4,   4, 10 , 5);
    # s.routeDMP(7);
    # s.ping(1, 8, "Hello World!\n");
    s.runTime(100);
 

if __name__ == '__main__':
    main()
