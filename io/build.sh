#!/usr/bin/env bash

# declare some useful vars
_pyver="cp$PYTHON_VERSION"
_abi="cp${PYTHON_VERSION}m"
_python="/opt/python/${_pyver}-${_abi}"/bin/python
_pip="/opt/python/${_pyver}-${_abi}"/bin/pip

# prepare env for build
yum install -y mysql-devel
# download and unpack mysqlclient source dist
"$_pip" download --no-binary=mysqlclient --no-deps "mysqlclient==$MYSQLCLIENT_VERSION"
tar xzvf "mysqlclient-${MYSQLCLIENT_VERSION}.tar.gz"

# build
cd "mysqlclient-$MYSQLCLIENT_VERSION"
"$_python" setup.py bdist_wheel
auditwheel repair "dist/mysqlclient-${MYSQLCLIENT_VERSION}-${_pyver}-${_abi}-linux_x86_64.whl" -w /root/io
cd /root

# prepare env for tests
"$_python" -m pip install pytest mock "/root/io/mysqlclient-${MYSQLCLIENT_VERSION}-${_pyver}-${_abi}_manylinux_x86_64.whl"
yum install -y mysql-server
chkconfig mysqld on
service mysqld start
mysql -e 'create database mysqldb_test charset utf8;'
cat <<EOM >tests/default.cnf
[MySQLdb-tests]
host = 127.0.0.1
port = 3306
user = root
database = mysqldb_test
default-character-set = utf8
EOM

# test
TESTDB=default.cnf "/opt/python/${_pyver}-${_abi}"/bin/pytest
