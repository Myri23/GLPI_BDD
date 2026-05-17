-- Tablespaces ts_data / ts_index (Oracle 19c Docker — chemin explicite)
-- Si échec : les tables utilisent le tablespace par défaut (USERS).
SET SERVEROUTPUT ON

DECLARE
   v_dir   VARCHAR2(4000);
   v_file  VARCHAR2(4000);
   v_ok    BOOLEAN := FALSE;
BEGIN
   BEGIN
      SELECT SUBSTR(file_name, 1, INSTR(file_name, '/', -1))
      INTO   v_dir
      FROM   dba_data_files
      WHERE  tablespace_name = 'USERS' AND ROWNUM = 1;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         DBMS_OUTPUT.PUT_LINE('WARN: impossible de lire dba_data_files — tablespaces ignorés.');
         RETURN;
   END;

   v_file := v_dir || 'cyglpi_ts_data01.dbf';
   BEGIN
      EXECUTE IMMEDIATE
         'CREATE TABLESPACE ts_data DATAFILE '''
         || v_file || ''' SIZE 100M AUTOEXTEND ON NEXT 50M MAXSIZE 2G';
      DBMS_OUTPUT.PUT_LINE('OK: tablespace TS_DATA -> ' || v_file);
      v_ok := TRUE;
   EXCEPTION
      WHEN OTHERS THEN
         IF SQLCODE IN (-1543, -1537, -1549) THEN
            DBMS_OUTPUT.PUT_LINE('INFO: TS_DATA existe déjà.');
            v_ok := TRUE;
         ELSE
            DBMS_OUTPUT.PUT_LINE('WARN TS_DATA: ' || SQLERRM);
         END IF;
   END;

   v_file := v_dir || 'cyglpi_ts_index01.dbf';
   BEGIN
      EXECUTE IMMEDIATE
         'CREATE TABLESPACE ts_index DATAFILE '''
         || v_file || ''' SIZE 50M AUTOEXTEND ON NEXT 25M MAXSIZE 1G';
      DBMS_OUTPUT.PUT_LINE('OK: tablespace TS_INDEX -> ' || v_file);
   EXCEPTION
      WHEN OTHERS THEN
         IF SQLCODE IN (-1543, -1537, -1549) THEN
            DBMS_OUTPUT.PUT_LINE('INFO: TS_INDEX existe déjà.');
         ELSE
            DBMS_OUTPUT.PUT_LINE('WARN TS_INDEX: ' || SQLERRM);
         END IF;
   END;

   IF NOT v_ok THEN
      DBMS_OUTPUT.PUT_LINE('Les objets seront créés dans USERS (défaut).');
   END IF;
END;
/
