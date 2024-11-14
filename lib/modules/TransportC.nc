#define AM_TRANSPORT 66

configuration TransportC{
	provides interface Transport;
}

implementation{
	components TransportP;
	components new TimerMilliC() as T_timer;
	TransportP.T_timer -> T_timer;

	//components new TimerMilliC() as packetTimer;
	//TransportP.packetTimer -> packetTimer;

	components new SimpleSendC(AM_TRANSPORT);
	TransportP.SimpleSend -> SimpleSendC;

	components new AMReceiverC(AM_TRANSPORT);

	Transport = TransportP.Transport;

	components RoutingTableC;
	TransportP.RoutingTable -> RoutingTableC.RoutingTable;

	components new ListC(socket_t, 30) as SocketList;
	TransportP.SocketList -> SocketList;

	components new QueueC(pack, 30) as packQ;
	TransportP.packQ -> packQ;

	components ForwardingC;
	TransportP.Forwarding -> ForwardingC.Forwarding;
	
}