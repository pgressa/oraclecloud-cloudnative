alter session set "_ORACLE_SCRIPT"=true;
CREATE USER orders IDENTIFIED BY "micronaut";
GRANT CONNECT, RESOURCE TO orders;
GRANT UNLIMITED TABLESPACE TO orders;
