#include "../../includes/packet.h"
#include "../../includes/channels.h"

// Configuration for the Flooding component
configuration FloodingC {
    provides interface Flooding;
}

implementation {
    components FloodingP; 
    components new SimpleSendC(10);  
    components new AMReceiverC(10);    

    // Connect interfaces
    Flooding = FloodingP.Flooding; 

    
    FloodingP.SimpleSend -> SimpleSendC; 
    FloodingP.Receive -> AMReceiverC; 
}