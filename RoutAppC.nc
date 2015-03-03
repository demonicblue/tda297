/* =========================================================== *
 * 
 * =========================================================== */

#include "Rout.h"

configuration RoutAppC
{
}

implementation
{
  /* ===== Listing of components to use ===== */

  components RoutC, MainC;
  components new TimerMilliC() as CTimer;
  components new TimerMilliC() as RTimer;
  components RandomC;
  
  /* Queue for messages to rout */
  components new QueueC(rout_msg_t,100) as Queue;

  /* Communication */
  components ActiveMessageC;
  components new AMSenderC(MESSAGE_CHANNEL)   as MessageSender;
  components new AMReceiverC(MESSAGE_CHANNEL) as MessageReceiver;

  /* ===== Connections between different components ===== */

  /* Implicitly means RoutC.Boot -> MainC.Boot */
  RoutC -> MainC.Boot;

  RoutC.PeriodTimer -> CTimer;

  RoutC.Random     -> RandomC;
  RoutC.RandomInit -> RandomC.Init;
  RoutC.RandomSeed -> RandomC.SeedInit;

  RoutC.MessageSend    -> MessageSender;
  RoutC.MessagePacket  -> MessageSender;
  RoutC.MessageReceive -> MessageReceiver;
  RoutC.MessageControl -> ActiveMessageC;

  RoutC.RouterQueue -> Queue;
}

