/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#include "ua_client.h"
#include "ua_client_internal.h"

UA_StatusCode
UA_Client_getEndpoints(UA_Client *client, const char *serverUrl,
                       size_t* endpointDescriptionsSize,
                       UA_EndpointDescription** endpointDescriptions) {
    if(client->state == UA_CLIENTSTATE_CONNECTED &&
        strncmp((const char*)client->endpointUrl.data, serverUrl, client->endpointUrl.length) != 0) {
        // client is already connected but to a different endpoint url.
        return UA_STATUSCODE_BADINVALIDARGUMENT;
    }

    UA_StatusCode retval = __UA_Client_connect(client, serverUrl, UA_FALSE, UA_FALSE);
    if(retval == UA_STATUSCODE_GOOD)
        retval = __UA_Client_getEndpoints(client, endpointDescriptionsSize, endpointDescriptions);

    UA_Client_disconnect(client);
    UA_Client_reset(client);
    return retval;
}

UA_StatusCode
UA_Client_findServers(UA_Client *client, const char *serverUrl,
                      size_t serverUrisSize, UA_String *serverUris,
                      size_t localeIdsSize, UA_String *localeIds,
                      size_t *registeredServersSize,
                      UA_ApplicationDescription **registeredServers) {
    /* Client is already connected but to a different endpoint url */
    if(client->state == UA_CLIENTSTATE_CONNECTED &&
       strncmp((const char*)client->endpointUrl.data, serverUrl, client->endpointUrl.length) != 0)
        return UA_STATUSCODE_BADINVALIDARGUMENT;

    UA_StatusCode retval = __UA_Client_connect(client, serverUrl, UA_TRUE, UA_FALSE);
    if(retval != UA_STATUSCODE_GOOD) {
        UA_Client_disconnect(client);
        UA_Client_reset(client);
        return retval;
    }

    /* Prepare the request */
    UA_FindServersRequest request;
    UA_FindServersRequest_init(&request);
    request.serverUrisSize = serverUrisSize;
    request.serverUris = serverUris;
    request.localeIdsSize = localeIdsSize;
    request.localeIds = localeIds;

    /* Send the request */
    UA_FindServersResponse response;
    UA_FindServersResponse_init(&response);
    __UA_Client_Service(client, &request, &UA_TYPES[UA_TYPES_FINDSERVERSREQUEST],
                        &response, &UA_TYPES[UA_TYPES_FINDSERVERSRESPONSE]);

    /* Process the response */
    retval = response.responseHeader.serviceResult;
    if(retval == UA_STATUSCODE_GOOD) {
        *registeredServersSize = response.serversSize;
        *registeredServers = response.servers;
        response.serversSize = 0;
        response.servers = NULL;
    } else {
        *registeredServersSize = 0;
        *registeredServers = NULL;
    }

    /* Clean up */
    UA_FindServersResponse_deleteMembers(&response);
    UA_Client_disconnect(client);
    UA_Client_reset(client);
    return retval;
}

UA_StatusCode
UA_Client_findServersOnNetwork(UA_Client *client, const char *serverUrl,
                               UA_UInt32 startingRecordId, UA_UInt32 maxRecordsToReturn,
                               size_t serverCapabilityFilterSize, UA_String *serverCapabilityFilter,
                               size_t *serverOnNetworkSize, UA_ServerOnNetwork **serverOnNetwork) {
    /* Client is already connected but to a different endpoint url */
    if(client->state == UA_CLIENTSTATE_CONNECTED &&
        strncmp((const char*)client->endpointUrl.data, serverUrl, client->endpointUrl.length) != 0)
        return UA_STATUSCODE_BADINVALIDARGUMENT;

    UA_StatusCode retval = __UA_Client_connect(client, serverUrl, UA_TRUE, UA_FALSE);
    if(retval != UA_STATUSCODE_GOOD) {
        UA_Client_disconnect(client);
        UA_Client_reset(client);
        return retval;
    }

    /* Prepare the request */
    UA_FindServersOnNetworkRequest request;
    UA_FindServersOnNetworkRequest_init(&request);
    request.startingRecordId = startingRecordId;
    request.maxRecordsToReturn = maxRecordsToReturn;
    request.serverCapabilityFilterSize = serverCapabilityFilterSize;
    request.serverCapabilityFilter = serverCapabilityFilter;

    /* Send the request */
    UA_FindServersOnNetworkResponse response;
    UA_FindServersOnNetworkResponse_init(&response);
    __UA_Client_Service(client, &request, &UA_TYPES[UA_TYPES_FINDSERVERSONNETWORKREQUEST],
                        &response, &UA_TYPES[UA_TYPES_FINDSERVERSONNETWORKRESPONSE]);

    /* Process the response */
    retval = response.responseHeader.serviceResult;
    if(retval == UA_STATUSCODE_GOOD) {
        *serverOnNetworkSize = response.serversSize;
        *serverOnNetwork = response.servers;
        response.serversSize = 0;
        response.servers = NULL;
    } else {
        *serverOnNetworkSize = 0;
        *serverOnNetwork = NULL;
    }

    /* Clean up */
    UA_FindServersOnNetworkResponse_deleteMembers(&response);
    UA_Client_disconnect(client);
    UA_Client_reset(client);
    return retval;
}
