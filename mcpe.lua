-- MCCPE Protocol dissector by 7kasper, forked from Intyre
mcpe_proto = Proto("PSPE","Protocol Support Pocket Edition")
local subtree

mcpe_proto.fields.id = ProtoField.string("mcpe.id", "Packet ID")
mcpe_proto.fields.dataid = ProtoField.string("mcpe.dataid", "MCPE ID")

function mcpe_proto.dissector(buffer,pinfo,tree)
	pinfo.cols.protocol = "MCCPE"

	local packetID = buffer(0,1)
	local length = buffer:len()

	m = mcpe_proto.fields

	pinfo.cols.info = "Unknown: " ..  packetID:uint() .. "(0x" .. packetID .. ")"
	subtree = tree:add(mcpe_proto, buffer(), "Raknet " .. packetID:uint() .. " (0x" .. packetID .. ")")
	subtree:add("Data Length: " .. length)
	subtree:add(m.id, buffer(0,1), "0x" .. buffer(0,1))
	local runsplit = false


	if (packetID:uint() == 1) then
		pinfo.cols.info = "RN: UC: Ping"
		subtree:add(buffer(1,8),"Ping ID: " .. buffer(1,8):uint64())
		subtree:add(buffer(9,16),"Magic: " ..  buffer(9,16))
		subtree:add(buffer(25,-1),"Client ID: " .. buffer(25,-1):uint64())
	elseif (packetID:uint() == 28) then
		pinfo.cols.info = "RN: UC: Pong"
		subtree:add(buffer(1,8), "Ping ID: " .. buffer(1,8):uint64())
		subtree:add(buffer(9,8), "Server ID: " ..buffer(9,8):uint64())
		subtree:add(buffer(17,16), "MAGIC: " .. buffer(17,16))
		subtree:add(buffer(33,2), "Length: " .. buffer(33,2):uint())
		subtree:add(buffer(35,-1),"Data: " .. buffer(35,-1):string())
	elseif (packetID:uint() == 5) then
		pinfo.cols.info = "RN: UC: Open Connection Request"
		subtree:add(buffer(1,16),"Magic: " .. buffer(1,16))
		subtree:add(buffer(17,1),"Protocol version: " .. buffer(17,1):uint())
		subtree:add(buffer(18,-1),"Null Payload")
	elseif (packetID:uint() == 6) then
		pinfo.cols.info = "RN: UC: Open Connection Reply"
		subtree:add(buffer(1,16),"Magic: " .. buffer(1,16))
		subtree:add(buffer(17,8),"Server ID: " .. buffer(17,8):uint64())
		subtree:add(buffer(25,1),"Server security: " .. buffer(25,1))
		subtree:add(buffer(26,-1),"MTU Size: " .. buffer(26,-1):uint())
	elseif (packetID:uint() == 7) then
		pinfo.cols.info = "RN: UC: Open Connection Request 2"
		subtree:add(buffer(1,16),"Magic: " .. buffer(1,16))
		subtree:add(buffer(17,5),"Address: " .. buffer(17,5))
		subtree:add(buffer(22,2),"Server Port: " .. buffer(22,2):uint())
		subtree:add(buffer(24,2),"MTU Size: " .. buffer(24,2):uint())
		subtree:add(buffer(26,8),"Client ID: " .. buffer(26,8):uint64())
	elseif (packetID:uint() == 8) then
		pinfo.cols.info = "RN: UC: Open Connection Reply 2"
		subtree:add(buffer(1,16),"Magic: " .. buffer(1,16))
		subtree:add(buffer(17,8),"Server ID: " .. buffer(17,8):uint64())
		subtree:add(buffer(25,5),"Client Address: " .. buffer(25,5))
		subtree:add(buffer(30,2),"Client port: " .. buffer(30,2):uint())
		subtree:add(buffer(32,2),"MTU Size: " .. buffer(32,2):uint())
		subtree:add(buffer(34,1),"Security: " .. buffer(34,1))
	elseif (packetID:uint() == 160) then
		pinfo.cols.info = "RN: C: NACK"
		subtree:add(buffer(1,2),"Unknown: " .. buffer(1,2))
   	 	subtree:add(buffer(3,1),"Additional Packet: " .. buffer(3,1))
		if(buffer(3,1):uint() == 0x01) then
			subtree:add(buffer(4,-1),"Packet number: " .. buffer(4,-1):le_uint())
		else
			pinfo.cols.info:append(" Multiple")
			getTime = subtree:add(buffer(4,6),"Multiple nack's")
			getTime:add(buffer(4,3),"Packet number: " .. buffer(4,3):le_uint())
			getTime:add(buffer(7,3),"Packet number: " .. buffer(7,3):le_uint())
		end
	elseif (packetID:uint() == 192) then
		pinfo.cols.info = "RN: C: ACK"
		subtree:add(buffer(1,2),"Unknown: " .. buffer(1,2))
   	 	subtree:add(buffer(3,1),"Additional Packet: " .. buffer(3,1))
		if(buffer(3,1):uint() == 0x01) then
			subtree:add(buffer(4,-1),"Packet number: " .. buffer(4,-1):le_uint())
		else
			pinfo.cols.info:append(" Multiple")
			getTime = subtree:add(buffer(4,6),"Multiple ack's")
			getTime:add(buffer(4,3),"Packet number: " .. buffer(4,3):le_uint())
			getTime:add(buffer(7,3),"Packet number: " .. buffer(7,3):le_uint())
		end
	elseif (packetID:uint() == 132) then
		pinfo.cols.info = "RN: C: Encapsulated"
		subtree:add(buffer(1,3), "Packet number: " .. buffer(1,3):le_uint())
		encap = tree:add(mcpe_proto, buffer(4), "Encapsulated " .. buffer(4,1):uint() .. " (0x" .. buffer(4,1) .. ")")
		
		local encapInfo = buffer(4,1)
		
		encap:add(buffer(4,1), "Info: " .. encapInfo:uint())
		encap:add(buffer(5,2), "Length: " .. buffer(5,2):uint())
		local bufIndex = 7
		if (bit.band(encapInfo:uint(), 0x7f)) >= 64 then 
			encap:add(buffer(7,3), "Message Index: " .. buffer(7,3):uint()) 
			bufIndex = bufIndex + 3
		end
		if (bit.band(encapInfo:uint(), 0x7f)) >= 96  then
			encap:add(buffer(10,3), "Order Index: " .. buffer(10,3):le_uint()) 
			encap:add(buffer(13,1), "Order Channel: " .. buffer(11,1):uint()) 
			bufIndex = bufIndex + 4
		end
		if (bit.band(encapInfo:uint(), 0x10)) ~= 0 then
			split = encap:add(buffer(bufIndex, 10), "Split")
			split:add(buffer(bufIndex,4), "Count: " .. buffer(bufIndex,4):uint()) 
			split:add(buffer(bufIndex + 4,2), "Id: " .. buffer(bufIndex + 4,2):uint()) 
			split:add(buffer(bufIndex + 6,4), "Order: " .. buffer(bufIndex + 6,4):uint()) 
			bufIndex = bufIndex + 10
		end
		
		--==PAYLOAD==--
		
		--packet = tree:add(mcpe_proto, buffer(bufIndex), "Packet " .. buffer(bufIndex,1):uint() .. " (0x" .. buffer(4,1) .. ")")
		encapIdB = buffer(bufIndex,1)
		encapId = encapIdB:uint()
		bufIndex = bufIndex + 1
		encap:add(encapIdB, "Encapsulated ID: " .. encapId)
		
		if encapId == 0 then
			pinfo.cols.info = "RN: E: Ping"
			packet = tree:add(mcpe_proto, buffer(bufIndex-1), "Ping " .. encapId .. " (0x" .. encapIdB .. ")")
			packet:add(buffer(bufIndex,8), "Time: " .. buffer(bufIndex,8):uint64())
			bufIndex = bufIndex + 8
		elseif encapId == 3 then
			pinfo.cols.info = "RN: E: Pong"
			packet = tree:add(mcpe_proto, buffer(bufIndex-1), "Pong " .. encapId .. " (0x" .. encapIdB .. ")")
			packet:add(buffer(bufIndex,8), "Time: " .. buffer(bufIndex,8):uint64())
			bufIndex = bufIndex + 8
		elseif encapId == 9 then
			pinfo.cols.info = "RN: E: Client Connect"
			packet = tree:add(mcpe_proto, buffer(bufIndex-1), "Client Connect " .. encapId .. " (0x" .. encapIdB .. ")")
			packet:add(buffer(bufIndex,8), "Client Id: " .. buffer(bufIndex,8):uint64())
			packet:add(buffer(bufIndex+8,8), "Ping Id: " .. buffer(bufIndex+8,8):uint64())
		    packet:add(buffer(bufIndex+16,1),"Security: " .. buffer(bufIndex+16,1))
			bufIndex = bufIndex + 16
		elseif encapId == 16 then
			pinfo.cols.info = "RN: E: Server Handshake"
			packet = tree:add(mcpe_proto, buffer(bufIndex-1), "Server Handshake " .. encapId .. " (0x" .. encapIdB .. ")")
			packet:add(buffer(bufIndex,8), "Client Id: " .. buffer(bufIndex,8):uint64())
		end
	--end
	elseif (packetID:uint() >= 0x80 or packetID:uint() <= 0x8f) then
		--PE PACKET!!!! YAAAAAYYYY!!!--
		
		data = buffer(4,-1)
		len = data:len() -4
		plength = 0
		i = 0
		total = 0
		while i<len do
			iS = i
			idp = data(i,1):uint()
			i = i + 1
			plength = data(i,2):uint() / 8
			i = i + 2
			if idp == 0x00 then

			elseif idp == 0x40 then
				i = i + 3
			elseif idp == 0x60 then
				i = i + 7
			end
			iX = i


			if (packetID:uint() == 0x80 and idp == 0x10) then
			    pinfo.cols.info = "RN: E: Server Handshake"
			    i = i - 3
			    packet = subtree:add(data(i,plength), "Server Handshake " .. total .. " (0x" .. idp .. ")")
			    i = i + 1
			    packet:add(data(i,5), "Client IP: " .. data(i,5))
			    i = i + 5
			    packet:add(data(i,2), "Client Port: " .. data(i,2):uint())
			    i = i + 2
			    i = i + 2--skip short
			    
			    while (data(i,-1):len() > 16) do
			        --i = i + 1
			        packet:add(data(i,5), "Server IP: " .. data(i,5))
			        i = i + 5
			        packet:add(data(i,2), "Server Port: " .. data(i,2):uint())
			        i = i + 2
			    end
			    
			    packet:add(data(i,8), "Ping Id: " .. data(i,8):uint64())
			    i = i + 8
			    packet:add(data(i,8), "Pong Id: " .. data(i,8):uint64())
			    i = i + 8
			    
			
			elseif data(i,1):uint() == 0x01 then
				part = subtree:add(data(i,plength),"LoginPacket")
				i = dataStart(part,data,iS,idp)

				i = getString(part,data,i,"Name")
				i = getInt(part,data,i,"Int")
				i = getInt(part,data,i,"Int")

			elseif data(i,1):uint() == 0x02 then
				part = subtree:add(data(i,plength), "LoginStatusPacket")
				i = dataStart(part,data,iS,idp)

				i = getInt(part,data,i,"Int")

			elseif data(i,1):uint() == 0x84 then
				part = subtree:add(data(i,plength), "ReadyPacket")
				i = dataStart(part,data,iS,idp);

				i = getByte(part,data,i,"Byte")

			elseif data(i,1):uint() == 0x0a then
				part = subtree:add(data(i,plength), "MessagePacket")
				i = dataStart(part,data,iS,idp);
				-- TODO: Update that for more message types.
				i = getString(part,data,i,"Sender")
				i = getString(part,data,i,"Message")

			elseif data(i,1):uint() == 0x0b then
				part = subtree:add(data(i,plength), "SetTimePacket")
				i = dataStart(part,data,iS,idp);

				i = getShortLE(part,data,i,"Time")
				i = getByte(part,data,i,"Daylight Cycle")

			elseif data(i,1):uint() == 0x0c then
				part = subtree:add(data(i,plength), "StartGamePacket")
				i = dataStart(part,data,iS,idp);

				i = getInt(part,data,i,"Seed")
				i = getInt(part,data,i,"Unknown")
				i = getInt(part,data,i,"Gamemode")
				i = getInt(part,data,i,"Entity ID")
				i = getFloat(part,data,i,"X")
				i = getFloat(part,data,i,"Y")
				i = getFloat(part,data,i,"Z")
				
			elseif data(i,1):uint() == 0x0d then
				part = subtree:add(data(i,plength), "AddPlayerPacket")
				i = dataStart(part,data,iS,idp);

				part:add(data(i,8), "Client iD: " .. data(i,8))
				i = i + 8
				i = getString(part,data,i,"Name")
				i = getInt(part,data,i,"Entity ID")
				i = getFloat(part,data,i,"X")
				i = getFloat(part,data,i,"Y")
				i = getFloat(part,data,i,"Z")
				part:add("Metadata until 0x7f")
				pinfo.cols.info:append(" <-- Stuff missing!!")
				
			elseif data(i,1):uint() == 0x0e then
				part = subtree:add(data(i,plength), "AddEnityPacket")
				i = dataStart(part,data,iS,idp);

				i = getInt(part,data,i,"Entity ID")
				i = getMobName(part,data,i)
				i = getFloat(part,data,i,"X")
				i = getFloat(part,data,i,"Y")
				i = getFloat(part,data,i,"Z")
				pinfo.cols.info:append(" <-- Unknown!!")

			elseif data(i,1):uint() == 0x8a then
				part = subtree:add(data(i,plength), "RemovePlayerPacket")
				i = dataStart(part,data,iS,idp);

				i = getInt(part,data,i,"Entity ID")
				part:add(data(i,8), "Client ID: " .. data(i,8))
				i = i + 8

			elseif data(i,1):uint() == 0x8c then
				part = subtree:add(data(i,plength), "AddEntityPacket")
				i = dataStart(part,data,iS,idp);

				pinfo.cols.info:append(" <-- Unknown!!")

			elseif data(i,1):uint() == 0x8d then
				part = subtree:add(data(i,plength), "RemoveEntityPacket")
				i = dataStart(part,data,iS,idp);

				i = getInt(part,data,i,"Entity ID")

			elseif data(i,1):uint() == 0x8e then
				part = subtree:add(data(i,plength), "AddItemEntityPacket")
				i = dataStart(part,data,iS,idp);

				i = getInt(part,data,i,"Int")
				i = getShort(part,data,i,"Short")
				i = getByte(part,data,i,"Byte")
				i = getShort(part,data,i,"Short")
				i = getFloat(part,data,i,"Float")
				i = getFloat(part,data,i,"Float")
				i = getFloat(part,data,i,"Float")
				i = getByte(part,data,i,"Byte")
				i = getByte(part,data,i,"Byte")
				i = getByte(part,data,i,"Byte")

			elseif data(i,1):uint() == 0x8f then
				part = subtree:add(data(i,plength), "TakeItemEntityPacket")
				i = dataStart(part,data,iS,idp);

				i = getInt(part,data,i,"Int")
				i = getInt(part,data,i,"Int")

			elseif data(i,1):uint() == 0x90 then
				part = subtree:add(data(i,plength), "MoveEntityPacket")
				i = dataStart(part,data,iS,idp);

				pinfo.cols.info:append(" <-- Unknown!!")

			elseif data(i,1):uint() == 0x93 then
				part = subtree:add(data(i,plength), "MoveEntityPacket_PosRot")
				i = dataStart(part,data,iS,idp);

				i = getInt(part,data,i,"Int")
				i = getFloat(part,data,i,"X")
				i = getFloat(part,data,i,"Y")
				i = getFloat(part,data,i,"Z")
				i = getFloat(part,data,i,"Yaw")
				i = getFloat(part,data,i,"Pitch")

			elseif data(i,1):uint() == 0x94 then
				part = subtree:add(data(i,plength), "MovePlayerPacket")
				i = dataStart(part,data,iS,idp);

				i = getInt(part,data,i,"Entity ID")
				i = getFloat(part,data,i,"X")
				i = getFloat(part,data,i,"Y")
				i = getFloat(part,data,i,"Z")
				i = getFloat(part,data,i,"Yaw")
				i = getFloat(part,data,i,"Pitch")

			elseif data(i,1):uint() == 0x95 then
				part = subtree:add(data(i,plength), "PlaceBlockPacket")
				i = dataStart(part,data,iS,idp);

				i = getInt(part,data,i,"Int")
				i = getInt(part,data,i,"Int")
				i = getInt(part,data,i,"Int")
				i = getByte(part,data,i,"Byte")
				i = getByte(part,data,i,"Byte")
				i = getByte(part,data,i,"Byte")
				i = getByte(part,data,i,"Byte")

			elseif data(i,1):uint() == 0x96 then
				part = subtree:add(data(i,plength), "RemoveBlockPacket")
				i = dataStart(part,data,iS,idp);

				i = getInt(part,data,i,"Entity ID")
				i = getInt(part,data,i,"X")
				i = getInt(part,data,i,"Y")
				i = getInt(part,data,i,"Z")

			elseif data(i,1):uint() == 0x97 then
				part = subtree:add(data(i,plength), "UpdateBlockPacket")
				i = dataStart(part,data,iS,idp);

				i = getInt(part,data,i,"X")
				i = getInt(part,data,i,"Z")
				i = getByte(part,data,i,"Y")
				i = getByte(part,data,i,"Block ID")
				i = getByte(part,data,i,"Block Data")

			elseif data(i,1):uint() == 0x98 then
				part = subtree:add(data(i,plength), "AddPaintingPacket")
				i = dataStart(part,data,iS,idp);

				pinfo.cols.info:append(" <-- Unknown!!")

			elseif data(i,1):uint() == 0x99 then
				part = subtree:add(data(i,plength), "ExplodePacket")
				i = dataStart(part,data,iS,idp);

				pinfo.cols.info:append(" <-- Unknown!!")

			elseif data(i,1):uint() == 0x9a then
				part = subtree:add(data(i,plength), "LevelEventPacket")
				i = dataStart(part,data,iS,idp);

				pinfo.cols.info:append(" <-- Unknown!!")

			elseif data(i,1):uint() == 0x9b then
				part = subtree:add(data(i,plength), "TileEventPacket")
				i = dataStart(part,data,iS,idp);

				i = getInt(part,data,i,"Int")
				i = getInt(part,data,i,"Int")
				i = getInt(part,data,i,"Int")
				i = getInt(part,data,i,"Int")
				i = getInt(part,data,i,"Int")

			elseif data(i,1):uint() == 0x9c then
				part = subtree:add(data(i,plength), "EntityEventPacket")
				i = dataStart(part,data,iS,idp);

				i = getInt(part,data,i,"Entity ID")
				i = getInt(part,data,i,"Event")


			elseif data(i,1):uint() == 0x9d then
				part = subtree:add(data(i,plength), "RequestChunkPacket")
				i = dataStart(part,data,iS,idp);

				i = getInt(part,data,i,"X")
				i = getInt(part,data,i,"Z")

			elseif data(i,1):uint() == 0x9f then
				part = subtree:add(data(i,plength), "PlayerEquipmentPacket")
				i = dataStart(part,data,iS,idp);

				i = getInt(part,data,i,"Entity ID")
				i = getShort(part,data,i,"Block ID")
				i = getShort(part,data,i,"Block Data")

			elseif data(i,1):uint() == 0xa0 then
				part = subtree:add(data(i,plength), "InteractPacket")
				i = dataStart(part,data,iS,idp);

				i = getInt(part,data,i,"Entity ID")
				i = getShort(part,data,i,"Block ID")
				i = getShort(part,data,i,"Block Data")

			elseif data(i,1):uint() == 0xa1 then
				part = subtree:add(data(i,plength), "UseItemPacket")
				i = dataStart(part,data,iS,idp);

				i = getInt(part,data,i,"X")
				i = getInt(part,data,i,"Y")
				i = getInt(part,data,i,"Z")
				i = getInt(part,data,i,"Unknown")
				i = getShort(part,data,i,"Block ID")
				i = getShort(part,data,i,"Block Data")
				i = getInt(part,data,i,"Entity ID")
				i = getFloat(part,data,i,"Float")
				i = getFloat(part,data,i,"Float")
				i = getFloat(part,data,i,"Float")

			elseif data(i,1):uint() == 0xa2 then
				part = subtree:add(data(i,plength), "PlayerActionPacket")
				i = dataStart(part,data,iS,idp);

				pinfo.cols.info:append(" <-- Unknown!!")

			elseif data(i,1):uint() == 0xa3 then
				part = subtree:add(data(i,plength), "SetEntityDataPacket")
				i = dataStart(part,data,iS,idp);

				pinfo.cols.info:append(" <-- Unknown!!")

			elseif data(i,1):uint() == 0xa4 then
				part = subtree:add(data(i,plength), "SetEntityMotionPacket")
				i = dataStart(part,data,iS,idp);

				i = getInt(part,data,i,"Entity ID")
				i = getShort(part,data,i,"Short")
				i = getShort(part,data,i,"Short")
				i = getShort(part,data,i,"Short")

			elseif data(i,1):uint() == 0xa5 then
				part = subtree:add(data(i,plength), "SetHealthPacket")
				i = dataStart(part,data,iS,idp);

				i = getByte(part,data,i,"Health")

			elseif data(i,1):uint() == 0xa6 then
				part = subtree:add(data(i,plength), "SetSpawnPositionPacket")
				i = dataStart(part,data,iS,idp);

				pinfo.cols.info:append(" <-- Unknown!!")

			elseif data(i,1):uint() == 0xa7 then
				part = subtree:add(data(i,plength), "AnimatePacket")
				i = dataStart(part,data,iS,idp);

				i = getByte(part,data,i,"Byte")
				i = getInt(part,data,i,"Entity ID")

			elseif data(i,1):uint() == 0xa8 then
				part = subtree:add(data(i,plength), "RespawnPacket")
				i = dataStart(part,data,iS,idp);

				pinfo.cols.info:append(" <-- Unknown!!")

			elseif data(i,1):uint() == 0xa9 then
				part = subtree:add(data(i,plength), "Packet::Packet(void)")
				i = dataStart(part,data,iS,idp);

				pinfo.cols.info:append(" <-- Unknown!!")

			elseif data(i,1):uint() == 0xaa then
				part = subtree:add(data(i,plength), "DropItemPacket")
				i = dataStart(part,data,iS,idp);

				i = getInt(part,data,i,"Entity ID")
				i = getByte(part,data,i,"Byte")
				i = getShort(part,data,i,"Block ID")
				i = getByte(part,data,i,"Stack Size")
				i = getShort(part,data,i,"Block Data")

			elseif data(i,1):uint() == 0xab then
				part = subtree:add(data(i,plength), "ContainerOpenPacket")
				i = dataStart(part,data,iS,idp);

				pinfo.cols.info:append(" <-- Unknown!!")

			elseif data(i,1):uint() == 0xac then
				part = subtree:add(data(i,plength), "ContainerClosePacket")
				i = dataStart(part,data,iS,idp);

				i = getByte(part,data,i,"Byte")

			elseif data(i,1):uint() == 0xad then
				part = subtree:add(data(i,plength), "ContainerSetSlotPacket")
				i = dataStart(part,data,iS,idp);

				pinfo.cols.info:append(" <-- Unknown!!")

			elseif data(i,1):uint() == 0xae then
				part = subtree:add(data(i,plength), "ContainerSetDataPacket")
				i = dataStart(part,data,iS,idp);

				pinfo.cols.info:append(" <-- Unknown!!")

			elseif data(i,1):uint() == 0xaf then
				part = subtree:add(data(i,plength), "ContainerSetContentPacket")
				i = dataStart(part,data,iS,idp);

				pinfo.cols.info:append(" <-- Unknown!!")

			elseif data(i,1):uint() == 0xb0 then
				part = subtree:add(data(i,plength), "ContainerAckPacket")
				i = dataStart(part,data,iS,idp);

				pinfo.cols.info:append(" <-- Unknown!!")

			elseif data(i,1):uint() == 0xb1 then
				part = subtree:add(data(i,plength), "ChatPacket")
				pinfo.cols.info:append(" <-- ChatPacket")
				i = dataStart(part,data,iS,idp);
				i = getByte(part,data,i,"Type")
				i = getString(part,data,i,"Message")
				
			elseif data(i,1):uint() == 0xb2 then
				part = subtree:add(data(i,plength), "SignUpdatePacket")
				i = dataStart(part,data,iS,idp);

				i = getShort(part,data,i,"X")
				i = getByte(part,data,i,"Y")
				i = getShort(part,data,i,"Z")

				for a=1,4,1 do
					slength = data(i,2):le_uint()
					part:add(data(i,2), "Length: " .. slength)
					i = i + 2
					if slength > 0 then
						part:add(data(i,slength), "Line "..a..": " .. data(i,slength):string())
						i = i + slength
					end
				end

			elseif data(i,1):uint() == 0xb3 then
				part = subtree:add(data(i,plength), "AdventureSettingsPacket")
				i = dataStart(part,data,iS,idp);

				pinfo.cols.info:append(" <-- Unknown!!")

			elseif data(i,1):uint() == 0x09 then

				part = subtree:add(data(i,plength), "Unknown")
				i = dataStart(part,data,iS,idp);

				part:add(data(i,8), "Unknown: " .. data(i,8))
				i = i + 8
				part:add(data(i,8), "Unknown: " .. data(i,8))
				i = i + 8
				i = getByte(part,data,i,"Unknown")
				pinfo.cols.info:append(" <-- Unknown!!")

			elseif data(i,1):uint() == 0x10 then
				part = subtree:add(data(i,plength), "Unknown")
				pinfo.cols.info:append(" <-- Unknown!!")
				i = dataStart(part,data,iS,idp);

				part:add(data(i,4), "Cookie: " .. data(i,4))
				i = i + 4
				part:add(data(i,1), "Security: " .. data(i,1))
				i = i + 1
				part:add(data(i,2), "Client Port: " .. data(i,2):uint())
				i = i + 2
				for j=0,9 do
					part:add(data(i,7), "Unknown: " .. data(i,7))
					i = i + 7
				end
				part:add(data(i,2), "Unknown: " .. data(i,2))
				i = i + 2
				part:add(data(i,8), "Unknown: " .. data(i,8))
				i = i + 8
				part:add(data(i,8), "Unknown: " .. data(i,8))
				i = i + 8

			elseif data(i,1):uint() == 0x13 then
				part = subtree:add(data(i,plength), "Unknown")
				pinfo.cols.info:append(" <-- Unknown!!")
				i = dataStart(part,data,iS,idp);

				part:add(data(i,4), "Cookie: " .. data(i,4))
				i = i + 4
				part:add(data(i,1), "Security: " .. data(i,1))
				i = i + 1
				part:add(data(i,2), "Client Port: " .. data(i,2):uint())
				i = i + 2
				part:add(data(i,5), "Unknown: " .. data(i,5))
				i = i + 5
				for j=0,8 do
					part:add(data(i,7), "Unknown: " .. data(i,7))
					i = i + 7
				end
				part:add(data(i,2), "Unknown: " .. data(i,2))
				i = i + 2
				part:add(data(i,8), "Unknown: " .. data(i,8))
				i = i + 8
				part:add(data(i,8), "Unknown: " .. data(i,8))
				i = i + 8

			elseif data(i,1):uint() == 0x9e then
				part = subtree:add(data(i,plength), "ChunkDataPacket")
				i = dataStart(part,data,iS,idp);

				i = getInt(part,data,i,"X")
				i = getInt(part,data,i,"Z")

			else
				part = subtree:add(data(i,plength),"Unknown")
				i = dataStart(part,data,iS,idp);

				pinfo.cols.info:append(" <-- Unknown!!")
			end
			i = iX + plength
			total = total + 1
		end
		pinfo.cols.info:append(" (" .. total .. ")")
	end

end

--[[ function getRakNetAdress(part, data, i) {
	part:add(data(i,1), name .. ": " .. data(i,1))
	--returmejrawl TODO: FINISH :P
} ]]--

function getString(tree,data,i,name)
	slength = data(i,2):uint()
	tree:add(data(i,2), "Length: " .. slength)
	tree:add(data(i+2,slength), name .. ": " .. data(i+2,slength):string())
	i = i + slength + 2
	return i
end

function dataStart(tree,data,i,idp)
	tree:add(data(i,1), "Container: " .. data(i,1))
	tree:add(data(i+1,2), "Data length: " .. plength)
	if data(i,1):uint() == 0x00 then
		i = i + 3
	elseif data(i,1):uint() == 0x40 then
		tree:add(data(i+3,3), "Packet counter: " .. data(i+3,3):le_uint())
		i = i + 6
	elseif data(i,1):uint() == 0x60 then
		tree:add(data(i+3,3), "Packet counter: " .. data(i+3,3):le_uint())
		tree:add(data(i+6,4), "Unknown: " .. data(i+6,4):le_uint())
		i = i + 10
	end
	m = mcpe_proto.fields
	tree:add(m.dataid, "0x" .. data(i,1))
	return i + 1
end

function getMobName(part,data,i)
	a = data(i,4):uint()
	name = "Unknown name"
	if a == 0x20 then
		name = "Zombie"
	elseif a == 0x21 then
		name = "Creeper"
	elseif a == 0x22 then
		name = "Skeleton"
	elseif a == 0x23 then
		name = "Spider"
	elseif a == 0x24 then
		name = "Zombie Pigman"
	end
	part:add(data(i,4), "Mob Type: " .. name)
	return i + 4
end

function getByte(part,data,i,name)
	part:add(data(i,1), name .. ": " .. data(i,1))
	return i + 1
end

function getShort(part,data,i,name)
	part:add(data(i,2), name .. ": " .. data(i,2):uint())
	return i + 2
end

function getShortLE(part,data,i,name)
	part:add(data(i,2), name .. ": " .. data(i,2):le_uint())
	return i + 2
end

function getInt(part,data,i,name)
	part:add(data(i,4), name .. ": " .. data(i,4):uint())
	return i + 4
end

function getFloat(part,data,i,name)
	part:add(data(i,4), name .. ": " .. data(i,4):float())
	return i + 4
end

udp_table = DissectorTable.get("udp.port")
udp_table:add(19132,mcpe_proto)
