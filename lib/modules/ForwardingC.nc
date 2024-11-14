#include "../../includes/channels.h"
#include "../../includes/protocol.h"
#include "../../includes/packet.h"

#define AM_FORWARDING 81

configuration ForwardingC{
    provides interface Forwarding;

}

implementation{
    components RoutingTableC, ForwardingP; 

    components new SimpleSendC(AM_FORWARDING);
    components new AMReceiverC(AM_FORWARDING);

    Forwarding = ForwardingP.Forwarding;
  
    ForwardingP.RoutingTable -> RoutingTableC.RoutingTable;

    ForwardingP.SimpleSend -> SimpleSendC;
    ForwardingP.Receive -> AMReceiverC.Receive;

}
    