/* This work is licensed under a Creative Commons CCZero 1.0 Universal License.
 * See http://creativecommons.org/publicdomain/zero/1.0/ for more information. */
/*
 * A simple server instance which registers with the discovery server (see server_lds.c).
 * Before shutdown it has to unregister itself.
 */


#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include "open62541.h"

#define DISCOVERY_SERVER_ENDPOINT "opc.tcp://localhost:4840"

UA_Logger logger = UA_Log_Stdout;
UA_Boolean running = true;

static void stopHandler(int sign) {
    UA_LOG_INFO(logger, UA_LOGCATEGORY_SERVER, "received ctrl-c");
    running = false;
}

static UA_StatusCode
readInteger(void *handle, const UA_NodeId nodeid, UA_Boolean sourceTimeStamp,
            const UA_NumericRange *range, UA_DataValue *dataValue) {
    dataValue->hasValue = true;
    UA_Variant_setScalarCopy(&dataValue->value, (UA_UInt32 *) handle, &UA_TYPES[UA_TYPES_INT32]);
    // we know the nodeid is a string
    UA_LOG_INFO(logger, UA_LOGCATEGORY_USERLAND, "Node read %.*s",
                nodeid.identifier.string.length, nodeid.identifier.string.data);
    UA_LOG_INFO(logger, UA_LOGCATEGORY_USERLAND, "read value %i", *(UA_UInt32 *) handle);
    return UA_STATUSCODE_GOOD;
}

static UA_StatusCode
writeInteger(void *handle, const UA_NodeId nodeid,
             const UA_Variant *data, const UA_NumericRange *range) {
    if (UA_Variant_isScalar(data) && data->type == &UA_TYPES[UA_TYPES_INT32] && data->data) {
        *(UA_UInt32 *) handle = *(UA_UInt32 *) data->data;
    }
    // we know the nodeid is a string
    UA_LOG_INFO(logger, UA_LOGCATEGORY_USERLAND, "Node written %.*s",
                nodeid.identifier.string.length, nodeid.identifier.string.data);
    UA_LOG_INFO(logger, UA_LOGCATEGORY_USERLAND, "written value %i", *(UA_UInt32 *) handle);
    return UA_STATUSCODE_GOOD;
}

int main(int argc, char **argv) {
    signal(SIGINT, stopHandler); /* catches ctrl-c */
    signal(SIGTERM, stopHandler);

    UA_ServerConfig config = UA_ServerConfig_standard;
    config.applicationDescription.applicationUri = UA_String_fromChars("urn:open62541.example.server_register");
    config.mdnsServerName = UA_String_fromChars("Sample Server");
    // See http://www.opcfoundation.org/UA/schemas/1.03/ServerCapabilities.csv
    //config.serverCapabilitiesSize = 1;
    //UA_String caps = UA_String_fromChars("LDS");
    //config.serverCapabilities = &caps;
    UA_ServerNetworkLayer nl = UA_ServerNetworkLayerTCP(UA_ConnectionConfig_standard, 16664);
    config.networkLayers = &nl;
    config.networkLayersSize = 1;
    UA_Server *server = UA_Server_new(config);

    /* add a variable node to the address space */
    UA_Int32 myInteger = 42;
    UA_NodeId myIntegerNodeId = UA_NODEID_STRING(1, "the.answer");
    UA_QualifiedName myIntegerName = UA_QUALIFIEDNAME(1, "the answer");
    UA_DataSource dateDataSource;
    dateDataSource.handle = &myInteger;
    dateDataSource.read = readInteger;
    dateDataSource.write = writeInteger;
    UA_VariableAttributes attr;
    UA_VariableAttributes_init(&attr);
    attr.description = UA_LOCALIZEDTEXT("en_US", "the answer");
    attr.displayName = UA_LOCALIZEDTEXT("en_US", "the answer");

    UA_Server_addDataSourceVariableNode(server, myIntegerNodeId,
                                        UA_NODEID_NUMERIC(0, UA_NS0ID_OBJECTSFOLDER),
                                        UA_NODEID_NUMERIC(0, UA_NS0ID_ORGANIZES),
                                        myIntegerName, UA_NODEID_NULL, attr, dateDataSource, NULL);


    // periodic server register after 10 Minutes, delay first register for 500ms
    UA_StatusCode retval = UA_Server_addPeriodicServerRegisterJob(server, DISCOVERY_SERVER_ENDPOINT, 10 * 60 * 1000, 500, NULL);
    //UA_StatusCode retval = UA_Server_addPeriodicServerRegisterJob(server, "opc.tcp://localhost:4840", 10*60*1000, 500, NULL);
    if (retval != UA_STATUSCODE_GOOD) {
        UA_LOG_ERROR(logger, UA_LOGCATEGORY_SERVER, "Could not create periodic job for server register. StatusCode %s", UA_StatusCode_name(retval));
        UA_String_deleteMembers(&config.applicationDescription.applicationUri);
        UA_Server_delete(server);
        nl.deleteMembers(&nl);
        return (int) retval;
    }

    retval = UA_Server_run(server, &running);
    if (retval != UA_STATUSCODE_GOOD) {
        UA_LOG_ERROR(logger, UA_LOGCATEGORY_SERVER, "Could not start the server. StatusCode %s", UA_StatusCode_name(retval));
        UA_String_deleteMembers(&config.applicationDescription.applicationUri);
        UA_Server_delete(server);
        nl.deleteMembers(&nl);
        return (int) retval;
    }

    // UNregister the server from the discovery server.
    retval = UA_Server_unregister_discovery(server, DISCOVERY_SERVER_ENDPOINT);
    //retval = UA_Server_unregister_discovery(server, "opc.tcp://localhost:4840" );
    if (retval != UA_STATUSCODE_GOOD) {
        UA_LOG_ERROR(logger, UA_LOGCATEGORY_SERVER, "Could not unregister server from discovery server. StatusCode %s", UA_StatusCode_name(retval));
        UA_String_deleteMembers(&config.applicationDescription.applicationUri);
        UA_Server_delete(server);
        nl.deleteMembers(&nl);
        return (int) retval;
    }

    UA_String_deleteMembers(&config.applicationDescription.applicationUri);
    UA_String_deleteMembers(&config.mdnsServerName);
    //UA_Array_delete(config.serverCapabilities, config.serverCapabilitiesSize, &UA_TYPES[UA_TYPES_STRING]);
    UA_Server_delete(server);
    nl.deleteMembers(&nl);

    return (int) retval;
}
