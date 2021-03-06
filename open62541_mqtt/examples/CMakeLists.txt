include_directories(${PROJECT_SOURCE_DIR}/include)
include_directories(${PROJECT_SOURCE_DIR}/plugins)
include_directories(${PROJECT_BINARY_DIR})

#############################
# Compiled binaries folders #
#############################

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin/examples)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin/examples)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin/examples)

list(APPEND LIBS ${open62541_LIBRARIES})
if(NOT WIN32)
  if(QNXNTO)
    list(APPEND LIBS socket)
    list(APPEND LIBS c)
    list(APPEND LIBS stdc++)
  else()
    list(APPEND LIBS pthread)
    if (NOT APPLE)
      list(APPEND LIBS rt)
    endif()
  endif()
else()
  list(APPEND LIBS ws2_32)
endif()
if(UA_ENABLE_MULTITHREADING)
  list(APPEND LIBS urcu-cds urcu urcu-common)
endif(UA_ENABLE_MULTITHREADING)

set(STATIC_OBJECTS $<TARGET_OBJECTS:open62541-object>)
if(WIN32 AND BUILD_SHARED_LIBS)
    # on windows the .dll.a file has to be used for the linker
    list(APPEND LIBS open62541)
    set(STATIC_OBJECTS "")
endif()

macro(add_example EXAMPLE_NAME EXAMPLE_SOURCE)
  add_executable(${EXAMPLE_NAME} ${STATIC_OBJECTS} ${EXAMPLE_SOURCE})
  target_link_libraries(${EXAMPLE_NAME} ${LIBS})
  assign_source_group(${EXAMPLE_SOURCE})
  add_dependencies(${EXAMPLE_NAME} open62541_amalgamation)
  set_target_properties(${EXAMPLE_NAME} PROPERTIES FOLDER "open62541/examples")
  if(UA_COMPILE_AS_CXX)
    set_source_files_properties(${EXAMPLE_SOURCE} PROPERTIES LANGUAGE CXX)
  endif()
endmacro()

#############
# Tutorials #
#############

add_example(tutorial_datatypes tutorial_datatypes.c)

add_example(tutorial_server_firststeps tutorial_server_firststeps.c)

add_example(tutorial_server_variable tutorial_server_variable.c)

add_example(tutorial_server_datasource tutorial_server_datasource.c)

add_example(tutorial_server_variabletype tutorial_server_variabletype.c)

add_example(tutorial_server_object tutorial_server_object.c)

if(UA_ENABLE_METHODCALLS)
  add_example(tutorial_server_method tutorial_server_method.c)
endif()

add_example(tutorial_client_firststeps tutorial_client_firststeps.c)

##################
# Example Server #
##################

add_example(server server.c)

##################
# Example Client #
##################

add_example(client client.c)

####################
# Feature Examples #
####################

add_example(server_mainloop server_mainloop.c)

add_example(server_instantiation server_instantiation.c)

add_example(server_repeated_job server_repeated_job.c)


if(NOT BUILD_SHARED_LIBS)
    # needs internal methods which are not exported in the dynamic lib
    add_example(server_readspeed server_readspeed.c)
    target_include_directories(server_readspeed PRIVATE ${PROJECT_SOURCE_DIR}/src ${PROJECT_SOURCE_DIR}/deps) # needs an internal header
endif()

add_example(server_inheritance server_inheritance.c)

if(NOT BUILD_SHARED_LIBS AND UA_BUILD_EXAMPLES_NODESET_COMPILER)
    # needs internal methods which are not exported in the dynamic lib
    add_example(server_nodeset "server_nodeset.c ${PROJECT_BINARY_DIR}/src_generated/nodeset.c")
    target_include_directories(server_nodeset PRIVATE ${PROJECT_SOURCE_DIR}/src ${PROJECT_SOURCE_DIR}/deps) # needs an internal header
endif()

if(UA_BUILD_SELFSIGNED_CERTIFICATE)
  find_package(OpenSSL REQUIRED)
  add_custom_command(OUTPUT server_cert.der ca.crt
                     COMMAND ${PYTHON_EXECUTABLE} ${PROJECT_SOURCE_DIR}/tools/certs/create_self-signed.py ${CMAKE_CURRENT_BINARY_DIR}
                     DEPENDS ${PROJECT_SOURCE_DIR}/tools/certs/create_self-signed.py
                             ${PROJECT_SOURCE_DIR}/tools/certs/localhost.cnf)
  add_custom_target(selfsigned ALL DEPENDS server_cert.der ca.crt)
  add_executable(server_certificate server_certificate.c ${STATIC_OBJECTS} server_cert.der ca.crt)
  target_link_libraries(server_certificate ${LIBS})
endif()

if(UA_ENABLE_DISCOVERY)
    add_example(discovery_server_lds discovery/server_lds.c)

    add_example(discovery_server_register discovery/server_register.c)

    add_example(discovery_client_find_servers discovery/client_find_servers.c)
    if(UA_ENABLE_DISCOVERY_MULTICAST)
        add_example(discovery_server_multicast discovery/server_multicast.c)
    endif()
endif()
