-- Timers affichage seulement (pas de DBMS_LOCK / DBMS_SESSION — compatible tous users)
CREATE OR REPLACE PACKAGE cytech_demo AS
    PROCEDURE section_start(p_name VARCHAR2, p_pause_sec NUMBER DEFAULT 0);
    PROCEDURE section_end;
END cytech_demo;
/

CREATE OR REPLACE PACKAGE BODY cytech_demo AS
    g_start   TIMESTAMP;
    g_section VARCHAR2(4000);

    PROCEDURE section_start(p_name VARCHAR2, p_pause_sec NUMBER DEFAULT 0) IS
    BEGIN
        g_section := p_name;
        g_start   := SYSTIMESTAMP;
        DBMS_OUTPUT.PUT_LINE(CHR(10) || RPAD('=', 72, '='));
        DBMS_OUTPUT.PUT_LINE('>>> DEBUT  : ' || p_name);
        DBMS_OUTPUT.PUT_LINE('    Heure  : ' || TO_CHAR(g_start, 'DD/MM/YYYY HH24:MI:SS.FF3'));
        IF NVL(p_pause_sec, 0) > 0 THEN
            DBMS_OUTPUT.PUT_LINE('    (Pause : utilisez demo.sql avec DEFINE demo_pause_sec)');
        END IF;
        DBMS_OUTPUT.PUT_LINE(RPAD('=', 72, '='));
    END section_start;

    PROCEDURE section_end IS
        v_secs NUMBER;
    BEGIN
        v_secs := (CAST(SYSTIMESTAMP AS DATE) - CAST(g_start AS DATE)) * 86400;
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 72, '-'));
        DBMS_OUTPUT.PUT_LINE('<<< FIN    : ' || g_section);
        DBMS_OUTPUT.PUT_LINE('    Duree  : ' || ROUND(v_secs, 3) || ' s');
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 72, '-'));
    END section_end;
END cytech_demo;
/
