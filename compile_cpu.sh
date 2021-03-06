set -e
set -v
export http_proxy=http://172.19.57.45:3128/
export https_proxy=http://172.19.57.45:3128/
version=0.0.0
app_version=0.0.0
cd ./python
#python change_version.py $version
cd ..

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/python3.7/lib
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin

cpu_num=10

PYTHONROOT=/usr/
PYTHON_INCLUDE_DIR_2=$PYTHONROOT/include/python2.7/
PYTHON_LIBRARY_2=$PYTHONROOT/lib/libpython2.7.so
PYTHON_EXECUTABLE_2=$PYTHONROOT/bin/python2.7

PYTHONROOT3=/usr/
PYTHON_INCLUDE_DIR_3=$PYTHONROOT3/include/python3.6m/
PYTHON_LIBRARY_3=$PYTHONROOT3/lib64/libpython3.6m.so
PYTHON_EXECUTABLE_3=$PYTHONROOT3/bin/python3.6m
/usr/bin/python -m pip install grpcio==1.33.2 grpcio-tools==1.33.2 numpy bce-python-sdk  pycrypto
/usr/bin/python3 -m pip install grpcio==1.33.2 grpcio-tools==1.33.2 numpy wheel

go env -w GO111MODULE=on
go env -w GOPROXY=https://goproxy.cn,direct
go get -u github.com/grpc-ecosystem/grpc-gateway/protoc-gen-grpc-gateway@v1.15.2
go get -u github.com/grpc-ecosystem/grpc-gateway/protoc-gen-swagger@v1.15.2
go get -u github.com/golang/protobuf/protoc-gen-go@v1.4.3
go get -u google.golang.org/grpc@v1.33.0

function change_py_version(){
py3_version=$1
case $py3_version in
    35)
        PYTHONROOT3=/usr/local/python3.5
        PYTHON_INCLUDE_DIR_3=$PYTHONROOT3/include/python3.5m
        PYTHON_LIBRARY_3=$PYTHONROOT3/lib/libpython3.5m.so
        PYTHON_EXECUTABLE_3=$PYTHONROOT3/bin/python3.5m
        ;;
    36)
        PYTHONROOT3=/usr/local/python3.6
        PYTHON_INCLUDE_DIR_3=$PYTHONROOT3/include/python3.6m/
        PYTHON_LIBRARY_3=$PYTHONROOT3/lib/libpython3.6m.so
        PYTHON_EXECUTABLE_3=$PYTHONROOT3/bin/python3.6m
        ;;
    37)
        PYTHONROOT3=/usr/local/python3.7
        PYTHON_INCLUDE_DIR_3=$PYTHONROOT3/include/python3.7m/
        PYTHON_LIBRARY_3=$PYTHONROOT3/lib/libpython3.7m.so
        PYTHON_EXECUTABLE_3=$PYTHONROOT3/bin/python3.7m
        ;;
esac
}
#git fetch upstream
#git merge upstream/develop

git submodule init
git submodule update

function cp_lib(){
cp /usr/lib64/libcrypto.so.10 $1
cp /usr/lib64/libssl.so.10 $1
}

function pack(){
mkdir -p bin_package
cd bin_package
WITHAVX=$1
WITHMKL=$2
if [ $WITHAVX = "ON" -a $WITHMKL = "OFF" ]; then
    mkdir -p serving-cpu-avx-openblas-$version
    cp ../build_server/output/demo/serving/bin/serving  serving-cpu-avx-openblas-$version
    cp ../build_server/third_party/Paddle/src/extern_paddle/paddle/lib/libpaddle_fluid.so serving-cpu-avx-openblas-$version
    cp_lib serving-cpu-avx-openblas-$version
    tar -czvf serving-cpu-avx-openblas-$version.tar.gz serving-cpu-avx-openblas-$version/
fi
if [ $WITHAVX = "OFF" -a $WITHMKL = "OFF" ]; then
    mkdir -p serving-cpu-noavx-openblas-$version
    cp ../build_server/output/demo/serving/bin/serving serving-cpu-noavx-openblas-$version
    cp ../build_server/third_party/Paddle/src/extern_paddle/paddle/lib/libpaddle_fluid.so serving-cpu-noavx-openblas-$version
    cp_lib serving-cpu-noavx-openblas-$version
    tar -czvf serving-cpu-noavx-openblas-$version.tar.gz serving-cpu-noavx-openblas-$version/
fi
if [ $WITHAVX = "ON" -a $WITHMKL = "ON" ]; then
    mkdir -p serving-cpu-avx-mkl-$version
    cp ../build_server/output/demo/serving/bin/* serving-cpu-avx-mkl-$version
    cp ../build_server/third_party/install/Paddle//third_party/install/mkldnn/lib/libdnnl.so.1 serving-cpu-avx-mkl-$version
    cp ../build_server/third_party/Paddle/src/extern_paddle/paddle/lib/libpaddle_fluid.so serving-cpu-avx-mkl-$version
    cp_lib serving-cpu-avx-mkl-$version
    tar -czvf serving-cpu-avx-mkl-$version.tar.gz serving-cpu-avx-mkl-$version/
fi
cd ..
}

function cp_whl(){
cd ..
mkdir -p whl_package
cd -
cp ./python/dist/paddle_serving_*-$version* ../whl_package \
|| cp ./python/dist/paddle_serving_app*-$app_version* ../whl_package
}

function clean_whl(){
if [ -d "python" ];then
rm -r python
fi
}

function compile_cpu(){
mkdir -p build_server
cd build_server
clean_whl
WITHAVX=$1
WITHMKL=$2
cmake -DPYTHON_INCLUDE_DIR=$PYTHON_INCLUDE_DIR_2 \
      -DPYTHON_LIBRARY=$PYTHON_LIBRARY_2 \
      -DPYTHON_EXECUTABLE=$PYTHON_EXECUTABLE_2 \
      -DWITH_AVX=$WITHAVX \
      -DWITH_MKL=$WITHMKL \
      -DSERVER=ON .. > compile_log
make -j$cpu_num >> compile_log
make -j$cpu_num >> compile_log
make install >> compile_log
cp_whl
cd ..
pack $WITHAVX $WITHMKL
}

function compile_cpu_py3(){
mkdir -p build_server_py3
cd build_server_py3
clean_whl
WITHAVX=$1
WITHMKL=$2
cmake -DPYTHON_INCLUDE_DIR=$PYTHON_INCLUDE_DIR_3 \
      -DPYTHON_LIBRARY=$PYTHON_LIBRARY_3 \
      -DPYTHON_EXECUTABLE=$PYTHON_EXECUTABLE_3 \
      -DWITH_AVX=$WITHAVX \
      -DWITH_MKL=$WITHMKL \
      -DSERVER=ON .. > compile_log
make -j$cpu_num >> compile_log
make -j$cpu_num >> compile_log
make install >> compile_log
cp_whl
cd ..
#pack $WITHAVX $WITHMKL
}


function upload_bin(){
    cd bin_package
    python ../bos_conf/upload.py bin serving-cpu-avx-openblas-$version.tar.gz
    python ../bos_conf/upload.py bin serving-cpu-avx-mkl-$version.tar.gz
    python ../bos_conf/upload.py bin serving-cpu-noavx-openblas-$version.tar.gz
    cd ..
}

function upload_whl(){
    cd whl_package
    python ../bos_conf/upload.py whl paddle_serving_server-$version-py2-none-any.whl
    python ../bos_conf/upload.py whl paddle_serving_server-$version-py3-none-any.whl
    cd ..
}

function compile(){
    #cpu-avx-openblas $1-avx  $2-mkl
    compile_cpu ON OFF
    compile_cpu_py3 ON OFF

    #cpu-avx-mkl
    compile_cpu ON ON

    #cpu-noavx-openblas
    compile_cpu OFF OFF
}

#compile
compile

#upload bin
upload_bin

#upload whl
upload_whl
