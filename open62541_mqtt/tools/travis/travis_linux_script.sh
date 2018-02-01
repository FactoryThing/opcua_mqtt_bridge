#!/bin/bash
set -ev

# Docker build test
if ! [ -z ${DOCKER+x} ]; then
    docker build -t open62541 .
    docker run -d -p 127.0.0.1:80:80 --name open62541 open62541 /bin/sh
    docker ps | grep -q open62541
    # disabled since it randomly fails
    # docker ps | grep -q open62541
    exit 0
fi

if [ $ANALYZE = "true" ]; then
    echo "=== Running static code analysis ===" && echo -en 'travis_fold:start:script.analyze\\r'
    if [ "$CC" = "clang" ]; then
        mkdir -p build
        cd build
        scan-build-3.9 cmake -DUA_BUILD_EXAMPLES=ON -DUA_BUILD_UNIT_TESTS=ON ..
        scan-build-3.9 -enable-checker security.FloatLoopCounter \
          -enable-checker security.insecureAPI.UncheckedReturn \
          --status-bugs -v \
          make -j
        cd .. && rm build -rf

        mkdir -p build
        cd build
        scan-build-3.9 cmake -DUA_ENABLE_AMALGAMATION=ON ..
        scan-build-3.9 -enable-checker security.FloatLoopCounter \
          -enable-checker security.insecureAPI.UncheckedReturn \
          --status-bugs -v \
          make -j
        cd .. && rm build -rf

        mkdir -p build
        cd build
        cmake -DUA_BUILD_EXAMPLES=ON ..
        make -j
        make lint
        cd .. && rm build -rf
    else
        cppcheck --template "{file}({line}): {severity} ({id}): {message}" \
            --enable=style --force --std=c++11 -j 8 \
            --suppress=duplicateBranch \
            --suppress=incorrectStringBooleanError \
            --suppress=invalidscanf --inline-suppr \
            -I include src plugins 2> cppcheck.txt
        if [ -s cppcheck.txt ]; then
            echo "====== CPPCHECK Static Analysis Errors ======"
            cat cppcheck.txt
            exit 1
        fi
    fi
    echo -en 'travis_fold:end:script.analyze\\r'
else
    echo -en "\r\n=== Building ===\r\n"

    echo -e "\r\n== Documentation and certificate build =="  && echo -en 'travis_fold:start:script.build.doc\\r'
    mkdir -p build
    cd build
    cmake -DCMAKE_BUILD_TYPE=Release -DUA_BUILD_EXAMPLES=ON -DUA_BUILD_SELFSIGNED_CERTIFICATE=ON ..
    make doc
    make doc_pdf
    make selfsigned
    cp -r doc ../../
    cp -r doc_latex ../../
    cp ./examples/server_cert.der ../../
    cd .. && rm build -rf
    echo -en 'travis_fold:end:script.build.doc\\r'

    echo -e "\r\n== Full Namespace 0 Generation ==" && echo -en 'travis_fold:start:script.build.ns0\\r'
    mkdir -p build
    cd build
    cmake -DCMAKE_BUILD_TYPE=Debug -DUA_ENABLE_GENERATE_NAMESPACE0=On -DUA_BUILD_EXAMPLES=ON  ..
    make -j
    cd .. && rm build -rf
    echo -en 'travis_fold:end:script.build.ns0\\r'
    # cross compilation only with gcc
    if [ "$CC" = "gcc" ]; then
        echo -e "\r\n== Cross compile release build for MinGW 32 bit =="  && echo -en 'travis_fold:start:script.build.cross_mingw32\\r'
        mkdir -p build && cd build
        cmake -DCMAKE_TOOLCHAIN_FILE=../tools/cmake/Toolchain-mingw32.cmake -DUA_ENABLE_AMALGAMATION=ON -DCMAKE_BUILD_TYPE=Release -DUA_BUILD_EXAMPLES=ON ..
        make -j
        zip -r open62541-win32.zip ../../doc_latex/open62541.pdf ../LICENSE ../AUTHORS ../README.md ./bin/examples/server.exe ./bin/examples/client.exe ./bin/libopen62541.dll.a open62541.h open62541.c
        cp open62541-win32.zip ..
        cd .. && rm build -rf
    	echo -en 'travis_fold:end:script.build.cross_mingw32\\r'

        echo -e "\r\n== Cross compile release build for MinGW 64 bit =="  && echo -en 'travis_fold:start:script.build.cross_mingw64\\r'
        mkdir -p build && cd build
        cmake -DCMAKE_TOOLCHAIN_FILE=../tools/cmake/Toolchain-mingw64.cmake -DUA_ENABLE_AMALGAMATION=ON -DCMAKE_BUILD_TYPE=Release -DUA_BUILD_EXAMPLES=ON ..
        make -j
        zip -r open62541-win64.zip ../../doc_latex/open62541.pdf ../LICENSE ../AUTHORS ../README.md ./bin/examples/server.exe ./bin/examples/client.exe ./bin/libopen62541.dll.a open62541.h open62541.c
        cp open62541-win64.zip ..
        cd .. && rm build -rf
    	echo -en 'travis_fold:end:script.build.cross_mingw64\\r'

        echo -e "\r\n== Cross compile release build for 32-bit linux =="  && echo -en 'travis_fold:start:script.build.cross_linux\\r'
        mkdir -p build && cd build
        cmake -DCMAKE_TOOLCHAIN_FILE=../tools/cmake/Toolchain-gcc-m32.cmake -DUA_ENABLE_AMALGAMATION=ON -DCMAKE_BUILD_TYPE=Release -DUA_BUILD_EXAMPLES=ON ..
        make -j
        tar -pczf open62541-linux32.tar.gz ../../doc_latex/open62541.pdf ../LICENSE ../AUTHORS ../README.md ./bin/examples/server ./bin/examples/client ./bin/libopen62541.a open62541.h open62541.c
        cp open62541-linux32.tar.gz ..
        cd .. && rm build -rf
    	echo -en 'travis_fold:end:script.build.cross_linux\\r'

        echo -e "\r\n== Cross compile release build for RaspberryPi =="  && echo -en 'travis_fold:start:script.build.cross_raspi\\r'
        mkdir -p build && cd build
        git clone https://github.com/raspberrypi/tools
        export PATH=$PATH:./tools/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian-x64/bin/
        cmake -DCMAKE_TOOLCHAIN_FILE=../tools/cmake/Toolchain-rpi64.cmake -DUA_ENABLE_AMALGAMATION=ON -DCMAKE_BUILD_TYPE=Release -DUA_BUILD_EXAMPLES=ON ..
        make -j
        tar -pczf open62541-raspberrypi.tar.gz ../../doc_latex/open62541.pdf ../LICENSE ../AUTHORS ../README.md ./bin/examples/server ./bin/examples/client ./bin/libopen62541.a open62541.h open62541.c
        cp open62541-raspberrypi.tar.gz ..
        cd .. && rm build -rf
    	echo -en 'travis_fold:end:script.build.cross_raspi\\r'
    fi

    echo -e "\r\n== Compile release build for 64-bit linux =="  && echo -en 'travis_fold:start:script.build.linux_64\\r'
    mkdir -p build && cd build
    cmake -DCMAKE_BUILD_TYPE=Release -DUA_ENABLE_AMALGAMATION=ON -DUA_BUILD_EXAMPLES=ON ..
    make -j
    tar -pczf open62541-linux64.tar.gz ../../doc_latex/open62541.pdf ../LICENSE ../AUTHORS ../README.md ./bin/examples/server ./bin/examples/client ./bin/libopen62541.a open62541.h open62541.c
    cp open62541-linux64.tar.gz ..
    cp open62541.h ../.. # copy single file-release
    cp open62541.c ../.. # copy single file-release
    cd .. && rm build -rf
	echo -en 'travis_fold:end:script.build.linux_64\\r'

    echo -e "\r\n== Building the C++ example =="  && echo -en 'travis_fold:start:script.build.example\\r'
    mkdir -p build && cd build
    cp ../../open62541.* .
    gcc -std=c99 -c open62541.c
    g++ ../examples/server.cpp -I./ open62541.o -lrt -o cpp-server
    cd .. && rm build -rf
	echo -en 'travis_fold:end:script.build.example\\r'

	echo "Compile as shared lib version" && echo -en 'travis_fold:start:script.build.shared_libs\\r'
	mkdir -p build && cd build
	cmake -DBUILD_SHARED_LIBS=ON -DUA_ENABLE_AMALGAMATION=ON -DUA_BUILD_EXAMPLES=ON ..
	make -j
	cd .. && rm build -rf
	echo -en 'travis_fold:end:script.build.shared_libs\\r'echo -e "\r\n==Compile multithreaded version==" && echo -en 'travis_fold:start:script.build.multithread\\r'
	mkdir -p build && cd build
	cmake -DUA_ENABLE_MULTITHREADING=ON -DUA_BUILD_EXAMPLES=ON ..
	make -j
	cd .. && rm build -rf
	echo -en 'travis_fold:end:script.build.multithread\\r'

    echo -e "\r\n== Compile without discovery version ==" && echo -en 'travis_fold:start:script.build.unit_test_valgrind\\r'
    mkdir -p build && cd build
    cmake -DUA_ENABLE_DISCOVERY=OFF -DUA_ENABLE_DISCOVERY_MULTICAST=OFF -DUA_BUILD_EXAMPLES=ON ..
    make -j
    cd .. && rm build -rf

    echo -e "\r\n== Compile discovery without multicast version =="
    mkdir -p build && cd build
    cmake -DUA_ENABLE_DISCOVERY=ON -DUA_ENABLE_DISCOVERY_MULTICAST=OFF -DUA_BUILD_EXAMPLES=ON ..
    make -j
    cd .. && rm build -rf


    echo -e "\r\n== Compile multithreaded version with discovery =="
    mkdir -p build && cd build
    cmake -DUA_ENABLE_MULTITHREADING=ON -DUA_ENABLE_DISCOVERY=ON -DUA_ENABLE_DISCOVERY_MULTICAST=ON -DUA_BUILD_EXAMPLES=ON ..
    make -j
    cd .. && rm build -rf
	echo -en 'travis_fold:end:script.build.multithread\\r'

    echo -e "\r\n== Debug build and unit tests (64 bit) ==" && echo -en 'travis_fold:start:script.build.unit_test_valgrind\\r'
    mkdir -p build && cd build
    cmake -DCMAKE_BUILD_TYPE=Debug -DUA_BUILD_EXAMPLES=ON -DUA_ENABLE_DISCOVERY=ON -DUA_ENABLE_DISCOVERY_MULTICAST=ON -DUA_BUILD_UNIT_TESTS=ON -DUA_ENABLE_COVERAGE=ON -DUA_ENABLE_VALGRIND_UNIT_TESTS=ON ..
    make -j && make test ARGS="-V"
	echo -en 'travis_fold:end:script.build.unit_test_valgrind\\r'

    # without valgrind
    # echo -e "\r\n== Debug build and unit tests without valgrind ==" && echo -en 'travis_fold:start:script.build.unit_test\\r'
    # cmake -DCMAKE_BUILD_TYPE=Debug -DUA_BUILD_EXAMPLES=ON -DUA_ENABLE_DISCOVERY=ON -DUA_ENABLE_DISCOVERY_MULTICAST=ON -DUA_BUILD_UNIT_TESTS=ON -DUA_ENABLE_COVERAGE=ON -DUA_ENABLE_VALGRIND_UNIT_TESTS=OFF ..
    # make -j && make test ARGS="-V"
    # (./bin/examples/server & export pid=$!; sleep 2; kill -INT $pid; wait $pid);
	# echo -en 'travis_fold:end:script.build.unit_test\\r'

    # only run coveralls on main repo, otherwise it fails uploading the files
    echo -e "\r\n== -> Current repo: ${TRAVIS_REPO_SLUG} =="
    if [ "$CC" = "gcc" ] && [ "${TRAVIS_REPO_SLUG}" = "open62541/open62541" ]; then
        echo -en "\r\n==   Building coveralls for ${TRAVIS_REPO_SLUG} ==" && echo -en 'travis_fold:start:script.build.coveralls\\r'
        coveralls -E '.*\.h' -E '.*CMakeCXXCompilerId\.cpp' -E '.*CMakeCCompilerId\.c' -r ../ || true # ignore result since coveralls is unreachable from time to time
        echo -en 'travis_fold:end:script.build.coveralls\\r'
    fi
    cd .. && rm build -rf
fi
