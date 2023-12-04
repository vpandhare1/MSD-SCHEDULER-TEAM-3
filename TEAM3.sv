module TEAM3;

	//Structure for input file
	typedef struct {
	int time_t;
        int core;
        int operation;
        logic [63:0] address;
    	}trace_input;
    	trace_input queue[$]; //Define queue of 16

	//Timing constraints
	int tRC = 115;
	int tRAS = 76;
	int tRP = 39;  
	int tRFC = 295;
	int tCL = 40; 
	int tRCD = 39; 
	int tRTP = 18; 
	int tBURST = 8;
	int tRRD_L = 12;
	int tRRD_S = 8;
	int tCWD = 38;
	int tWR = 30;
	int tCCD_L = 12;
	int tCCD_S = 8;
	int tCCD_L_WR = 48;
	int tCCD_S_WR = 8;
	int tCCD_L_RTW = 16;
	int tCCD_S_RTW = 16;
	int tCCD_L_WTR = 70;
	int tCCD_S_WTR = 52;	


	//Varibles required for parsing file
	int Ip;
    	string line;
	string input_trace_file;
    	string output_commands_file;
    	int Op;
    	int debug = 0; // Debug flag
	int present_time = 0;


	//Command line arguments 
	initial begin
        	//Input command
		if (!$value$plusargs("Input=%s", input_trace_file)) begin
            	input_trace_file = "tracecp0.txt"; //Default name
        	end
	        
		//Output command
        	if (!$value$plusargs("Output=%s", output_commands_file)) begin
            	output_commands_file = "dram.txt"; //Default name
        	end

        	//Debug command
        	debug = $test$plusargs("debug");

        	//Open input file
        	Ip = $fopen(input_trace_file, "r");
        	if (Ip == 0) begin
            	$display("Failed to open file: %s", input_trace_file);
            	$finish;
        	end

        	//Open output file
        	Op = $fopen(output_commands_file, "w");
        	if (Op == 0) begin
            	$display("Failed to open output file: %s", output_commands_file);
            	$finish;
        	end

        	//Read till end of file
        	while (!$feof(Ip)) begin
            	$fgets(line, Ip); //get line from input file
            	if (line != "") begin
                trace_input t1;
		//Scan and categorize the line
                $sscanf(line, "%d %d %d %h", t1.time_t, t1.core, t1.operation, t1.address);
               

                //Queue logic
                if (queue.size() < 16) begin
                    queue.push_back(t1); //push the memory requests from t1 to back of the queue
                    pmr(queue.pop_front()); //task is executing using elements of queue
                end else begin
                    $display("Queue is full!"); //Full = busy
                end

                //Function for debug
                if (debug) begin
                    $display("Time=%0d, Core=%0d, Operation=%0d, Address=%0h", t1.time_t, t1.core, t1.operation, t1.address);
                end
            end
        end

        //General queue operation
        foreach (queue[i]) begin
            pmr(queue[i]);
        end

        // Close the files
        $fclose(input_trace_file);
        $fclose(output_commands_file);
    end


    //Task to process a memory request
    task pmr(trace_input t2);
        automatic logic[15:0] row = t2.address[33:18];
        automatic logic[9:4] high_column = t2.address[17:12];
        automatic logic[1:0] bank = t2.address[11:10];
        automatic logic[2:0] bank_group = t2.address[9:7]; 
        automatic logic channel = t2.address[6]; 
        automatic logic[3:0] low_column = t2.address[5:2]; 
        automatic logic[1:0] byte_select = t2.address[1:0]; 
	automatic logic[1:0] ba = bank;
	automatic logic[2:0] bg = bank_group;
	
	automatic int time1;
	if (t2.time_t+2 > present_time)
		time1 = t2.time_t+2;
	else
		time1 = present_time;

        //ACT command
        $fwrite(Op,"%d %d ACT0 %d %d 0x%h\n", time1, channel, bank_group, bank, row);
	$fwrite(Op,"%d %d ACT1 %d %d 0x%h\n", time1+2, channel, bank_group, bank, row);
        time1 = time1 + 2 + (tRCD*2); //ADD tRCD and update time1
       //Operation READ
        if (t2.operation == 0) begin 
            $fwrite(Op,"%d %d RD0 %d %d 0x%h%h\n", time1, channel, bank_group, bank, high_column, low_column); //READ command
	    $fwrite(Op,"%d %d RD1 %d %d 0x%h%h\n", time1+2, channel, bank_group, bank, high_column, low_column);
            time1 = time1 + 2 + ((tCL + tBURST + tRTP)*2); //Add tCL + tBURST and update time1
        end else if (t2.operation == 1) begin //Operation WRITE
            $fwrite(Op,"%d %d WR0 %d %d 0x%h%h\n", time1, channel, bank_group, bank, high_column, low_column);
            $fwrite(Op,"%d %d WR1 %d %d 0x%h%h\n", time1+2, channel, bank_group, bank, high_column, low_column);
            time1 = time1 + 2 + (tWR*2); //Add tWR and update time1
        end else if (t2.operation == 2) begin // Operation READ
            $fwrite(Op,"%d %d RD0 %d %d 0x%h%h\n", time1, channel, bank_group, bank, high_column, low_column);
            $fwrite(Op,"%d %d RD1 %d %d 0x%h%h\n", time1+2, channel, bank_group, bank, high_column, low_column);
            time1 = time1 + 2 + ((tCL + tBURST + tRTP)*2); //
	end
        //PRECHARGE command
        $fwrite(Op,"%d %d PRE %d %d\n", time1, channel, bank_group, bank);
	 present_time = time1 + (tRP*2); //Add tRP 
	
    endtask


    

endmodule

