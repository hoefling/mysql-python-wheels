#!/usr/bin/env bash

# declare some useful vars
INTERPRETER="cp$PYTHON_VERSION"
ABI="${INTERPRETER}m"
_prefix="/opt/python/${INTERPRETER}-${ABI}"
_python="$_prefix"/bin/python
_pip="${_prefix}"/bin/pip

# prepare env for build
# add atomic repo for mysql 5.5
yum install -y wget
wget -q http://www.atomicorp.com/installers/atomic
sed -i 's/query=$INPUTTEXT/query="yes"/g; /check_input "/d' atomic
sh ./atomic
yum install -y mysql-devel
# download and unpack mysqlclient source dist
"$_pip" download --no-binary=mysqlclient --no-deps "mysqlclient==$MYSQLCLIENT_VERSION"
tar xzvf "mysqlclient-${MYSQLCLIENT_VERSION}.tar.gz"

# build
cd "mysqlclient-$MYSQLCLIENT_VERSION"
"$_python" setup.py bdist_wheel clean
auditwheel repair "dist/mysqlclient-${MYSQLCLIENT_VERSION}-${INTERPRETER}-${ABI}-linux_x86_64.whl" -w /root/io
rm -rf build dist mysqlclient.egg-info __pycache__

# prepare env for tests
"$_python" -m pip install pytest mock "/root/io/mysqlclient-${MYSQLCLIENT_VERSION}-${INTERPRETER}-${ABI}-manylinux1_x86_64.whl"
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
default-character-set = utf8mb4
EOM

# test
TESTDB=default.cnf "${_prefix}"/bin/pytest
