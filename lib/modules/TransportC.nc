#define AM_TRANSPORT 66

configuration TransportC{
	provides interface Transport;
}

implementation{
	components TransportP, ForwardingC; 
	components new TimerMilliC() as T_timer;
	TransportP.T_timer -> T_timer;	

	components new ListC(socket_t, 30) as SocketList;
	TransportP.SocketList -> SocketList;

	components new QueueC(tcp_pack, 10) as packQ;
	TransportP.packQ -> packQ;

	
    Transport = TransportP.Transport;

	TransportP.Forwarding -> ForwardingC; 
}