 /* Strict Priority Queueing (SP)
 *
 * Variables:
 * queue_num_: number of CoS queues
 * thresh_: ECN marking threshold
 * mean_pktsize_: configured mean packet size in bytes
 * marking_scheme_: Disable ECN (0), Per-queue ECN (1) and Per-port ECN (2)
 */

#include "wrps.h"
#include "flags.h"
#include "math.h"


//#define max(arg1,arg2) (arg1>arg2 ? arg1 : arg2)
//#define min(arg1,arg2) (arg1<arg2 ? arg1 : arg2)

static class wrpsClass : public TclClass {
 public:
	wrpsClass() : TclClass("Queue/WRPS") {}
	TclObject* create(int, const char*const*) {
		return (new wrps);
	}
} class_wrps;

void wrps::enque(Packet* p)
{

	queue_length_++;
	hdr_ip *iph = hdr_ip::access(p);
	int prio = iph->prio();
    //    printf("%d   ",prio);
	hdr_flags* hf = hdr_flags::access(p);
	
	//queue length exceeds the queue limit
	//whx lddctcp
	if(queue_length_ > qlim_)
	{
		printf("%s ","pktdrop");
		drop(p);
		queue_length_--;
		return;
	}
	//whx lddctcp

	//Enqueue packet
	q_[prio]->enque(p);

    //Enqueue ECN marking: Per-queue or Per-port
    if(queue_length_ >marking_thresh_)
    {
        if (hf->ect()) //If this packet is ECN-capable
            hf->ce()=1;
    }
}

Packet* wrps::deque()
{
if(queue_length_ > 0)
    {

// following code is priority schedule algorithm.
         if(q_[0]->length() > 0 )
         {  
//printf(" %d %d",0,q_[0]->length());
queue_length_--;
            Packet* p = q_[0]->deque(); 
            return (p);
         }
         else if(q_[1]->length() > 0 )
         {
//printf(" %d %d",1,q_[0]->length());
queue_length_--;
            Packet* p = q_[1]->deque(); 
            return (p);
         }
}

/*
    if(queue_length_ > 0)
    {
	//    queue_length_--;
	   // printf("%d ",queue_length_);
       	    for(int i = cur_queue_; i <= queue_num_; i++)
	    {
	         //  printf("%d ", cur_queue_);
		    if(q_[i]->length() > 0 )
                   {
                        if (q_weight_counter[i] > 0) {
	                       queue_length_--;
		               q_weight_counter[i]--;   
                               if (q_weight_counter[i] == 0) {
                                       cur_queue_ ++;
                                       if (cur_queue_ > queue_num_) {
                                               cur_queue_ = 0; 
                                               reset_queue_weight();
                                       }                     
			       }
		               Packet* p = q_[i]->deque();                               
		               return (p);
                        }
		    } else {
                         cur_queue_++;
                         if (cur_queue_ > queue_num_) {
                                       cur_queue_ = 0; 
                                       reset_queue_weight();
                        }
                    }
            }
            
    }
*/
    return NULL;
}
void wrps::reset_queue_weight()
{
	 for(int i = 0; i <= queue_num_; i++)
	    {
                 q_weight_counter[i] = q_weight[i];
	    }

}

