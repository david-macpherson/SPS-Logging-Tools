import re
import os
import json
import shutil
import argparse

from types import SimpleNamespace


parser = argparse.ArgumentParser(description="Processor")

parser.add_argument("directory", help="The main logs directory")

args = parser.parse_args()
config = vars(args)


directoryPath = config["directory"] 
filteredDir =  os.path.join(os.getcwd(), os.path.basename(directoryPath))

directory = os.fsencode(directoryPath)

listOfUeLogs = []

for file in os.listdir(directoryPath):
    filename = os.fsdecode(file)
    if filename.startswith("sps-application"):
        listOfUeLogs.append(filename)
    


if os.path.exists(filteredDir):
    shutil.rmtree(filteredDir)

os.mkdir(filteredDir)


def extractTimeData(LogPath):
    timeArray=[]
    with open(LogPath) as logFile:
        for line in logFile:
            log = json.loads(line)
            timeArray.append(log["ts"])
    
    timeArray.sort()
    firstEntry = timeArray[0]
    lastEntry = timeArray[len(timeArray) - 1]
    return firstEntry,lastEntry, lastEntry-firstEntry
    

def getWebsocketDisconnectTimes(LogPath):
        player={}
        instance={}
        playerPingFailed=False
        with open(LogPath) as logFile:
            for line in logFile:
                log = json.loads(line)
                if str(log["msg"]).startswith("Player ping response failed"):
                    playerPingFailed=True

                if str(log["msg"]).startswith("websocket: close"):
                    if "player" in log:
                        player["ts"] = log["ts"]
                        player["reason"] = log["msg"]
                    if "instance" in log:
                        instance["ts"] = log["ts"]
                        instance["reason"] = log["msg"]                        

        message = ""

        if "ts" not in player and "ts" not in instance:
            message = "no closure recorded"

        elif "ts" not in player:               
            message = "instance closed first at " + str(instance["ts"]) + " with reason: "+ str(instance["reason"]) + " player no record of instance websocket closing"
        
        elif "ts" not in instance:
            message = "player closed first at " + str(player["ts"]) + " with reason: "+ str(player["reason"]) + " instance no record of instance websocket closing"      

        elif "ts" in instance and "ts" in player:
           
            if player["ts"] > instance["ts"]:      
                message = "instance closed first at " + str(instance["ts"]) + " with reason: "+ str(instance["reason"]) + " player then closed at " + str(player["ts"]) + " with reason: " + str(player["reason"])

            if instance["ts"] > player["ts"]:
                message = "player closed first at " + str(player["ts"]) + " with reason: "+ str(player["reason"]) + " instance then closed at " + str(instance["ts"]) + " with reason: " + str(instance["reason"])

        return playerPingFailed, message
        

def getUELogPath(logDirPath,instanceID):

    for file in os.listdir(logDirPath):
        filename = os.fsdecode(file)
        if filename.startswith(instanceID):
            return os.path.join(logDirPath, filename)
    return None

def extractSSLogs(ssLogPath,outputDir,playerID,instanceID=None):
    # Safety check to ensure the instance ID and player id is set
    
    regex = re.compile("("+ playerID +")")
    filteredFile = os.path.join(outputDir,playerID + ".log")

    if instanceID != None:
        regex = re.compile("("+ playerID +")|(" + instanceID +")")
        filteredFile = os.path.join(outputDir,playerID + " - " + instanceID + ".log")
    
    with open(ssLogPath) as f:
        for line in f:

            result = regex.search(line)

            if result:
                with open(filteredFile, "a") as i2p:
                    i2p.write(line)
    
    return filteredFile



# Loop through the folder and look for a file with the instanceID
for file in os.listdir(directory):
    filename = os.fsdecode(file)

    if filename.endswith("signalling-server.log"):
        ssLogPath = os.path.join(directoryPath,filename)
        outputDir = os.path.join(filteredDir,os.fsdecode(file))
        overviewFilePath = os.path.join(filteredDir,filename+".csv")

        os.mkdir(outputDir)
        
        # Create and empty player dictionary
        players = {}

        # Loop through the folder and look for a file with the instanceID
        with open(ssLogPath) as ssLog:
            for line in ssLog:
                try:
                    
                    ssLogData = json.loads(line)

                    if "message" in ssLogData:
                        if "type" in ssLogData["message"]:
                            # Add the Player ID if authenticated
                            if ssLogData["message"]["type"] == "authenticationResponse":
                                if ssLogData["message"]["outcome"] == "AUTHENTICATED":
                                    players[ssLogData["player"]] = None
                                    continue
                            # If the message is instance state
                            if ssLogData["message"]["type"] == "instanceState":
                                if players[ssLogData["player"]] == None:
                                    players[ssLogData["player"]] = ssLogData["message"]["id"]
                                    continue

                except:
                    pass
        

        with open(overviewFilePath, "a") as overviewFile:
            overviewFile.write("playerID" + "," + "instanceID" + "," + "unixEpochStartTime" + ","  + "unixEpochEndTime" + "," + "duration" + "," +"playerPingFailed" + "," + "closure notes" + "," + "ueLogPath" +"\n")
                    

        for playerID,instanceID in players.items():
            
            filteredLog = extractSSLogs(ssLogPath,outputDir,playerID,instanceID)
            startTime, endTime, diffTime =  extractTimeData(filteredLog)
            
            playerPingFailed, webSocketNotes,  = getWebsocketDisconnectTimes(filteredLog)

            if instanceID != None:
                ueLogFileName = next((x for x in listOfUeLogs if str(x).startswith(instanceID)), None)
                ueLogFilePath = None
                if ueLogFileName != None:
                    ueLogFilePath = os.path.join(directoryPath, ueLogFileName)


            with open(overviewFilePath, "a") as overviewFile:
                overviewFile.write(playerID + "," + str(instanceID) + "," + str(startTime) + ","  + str(endTime) + "," + str(diffTime) + "," + str(playerPingFailed) +  "," + str(webSocketNotes) + "," + str(ueLogFilePath) + "\n")