-- Rafraîchir les vues matérialisées sur CERGY_SITE et PAU_SITE
BEGIN
   DBMS_MVIEW.REFRESH('MV_Site', 'C');
   DBMS_MVIEW.REFRESH('MV_Role', 'C');
   DBMS_MVIEW.REFRESH('MV_Permission', 'C');
   DBMS_MVIEW.REFRESH('MV_RolePermission', 'C');
END;
/
