@echo off
setlocal

goto start

:generateSql
setlocal
set "outFile=%~1%"

For /F "Tokens=2* skip=2" %%A In ('reg query HKLM\SOFTWARE\Wow6432Node\Dualog\DGS /v DatabasePassword 2^>nul') Do (set regval=%%B)
IF NOT DEFINED regval (
	For /F "Tokens=2* skip=2" %%C In ('reg query HKLM\SOFTWARE\Dualog\DGS /v DatabasePassword 2^>nul') Do set (set regval=%%D)
	IF NOT DEFINED regval (
		@FOR /F "tokens=2* delims=	 " %%I IN ('reg query HKLM\SOFTWARE\Wow6432Node\Dualog\DGS /v DatabasePassword 2^>nul') DO (set regval=%%J)
		IF NOT DEFINED regval (
			@FOR /F "tokens=2* delims=	 " %%K IN ('reg query HKLM\SOFTWARE\Dualog\DGS /v DatabasePassword 2^>nul') DO (set regval=%%L)
		)
	)
)

echo WHENEVER SQLERROR EXIT SQL.SQLCODE>%outFile%
echo connect g4vessel/%regval%@127.0.0.1:1521/xe>%outFile%
echo create or replace PROCEDURE "CREATE_AESM_FOLDERS">>%outFile%
echo  IS>>%outFile%
echo           folderowner   NUMBER;>>%outFile%
echo           companyid number;>>%outFile%
echo           inboxid number;>>%outFile%
echo           sentboxid number;>>%outFile%
echo           foldercount number;>>%outFile%
echo           --sharedcount number;>>%outFile%
echo           inboxcount number;>>%outFile%
echo           newfolderid number;>>%outFile%
echo  BEGIN>>%outFile%
echo          -- Find company id>>%outFile%
echo          select max(com_companyid) into companyid from dv_company;>>%outFile%
echo          -- Ship account>>%outFile%
echo          -- Cheking if Ship account exists>>%outFile%
echo          select usr.usr_userid into folderowner>>%outFile%
echo          from dv_user usr>>%outFile%
echo          join dv_vessel ves on usr.ves_vesselid = ves.ves_vesselid>>%outFile%
echo          where lower(usr.usr_email) like 'imo%%'>>%outFile%
echo          and nvl(usr.usr_rowstatus,0) = 0;>>%outFile%
echo          if folderowner is null then>>%outFile%
echo           return;>>%outFile%
echo          end if;>>%outFile%
echo          -- Checking if Inbox exists for Ship account>>%outFile%
echo          select count(*) into inboxcount from dv_imapfolder>>%outFile%
echo          where usr_userid = folderowner and imf_inbox = 1;>>%outFile%
echo          if inboxcount = 0 then>>%outFile%
echo           -- Inbox doesn't exist. Create it>>%outFile%
echo            select dv_imapfolder_seq.nextval into inboxid from dual;>>%outFile%
echo            insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo            values (inboxid, inboxid, folderowner, 1);>>%outFile%
echo            execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(inboxid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo            insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                           IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                           IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                        values(dv_imapfolderaccess_seq.nextval, inboxid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                              1, 1, 1, 1, 1, 1,>>%outFile%
echo                              1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX');>>%outFile%
echo           -- Sent doesn't exist. Create it>>%outFile%
echo            select dv_imapfolder_seq.nextval into sentboxid from dual;>>%outFile%
echo            insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_UID,USR_USERID, IMF_FOLDERNAME,IMF_INBOX)>>%outFile%
echo            values (sentboxid, sentboxid, folderowner, 'Sent Items', 0);>>%outFile%
echo            execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(sentboxid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo            insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                           IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                           IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                        values(dv_imapfolderaccess_seq.nextval, sentboxid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                              1, 1, 1, 1, 1, 1,>>%outFile%
echo                              1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items');>>%outFile%
echo          else>>%outFile%
echo            select imf_imapfolderid into inboxid from dv_imapfolder>>%outFile%
echo                  where usr_userid = folderowner and imf_inbox = 1;>>%outFile%
echo            select imf_imapfolderid into sentboxid from dv_imapfolder>>%outFile%
echo                  where usr_userid = folderowner and imf_foldername = 'Sent Items';>>%outFile%
echo          end if;>>%outFile%
echo         -->>%outFile%
echo         -- 1 Accounts>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Accounts folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Accounts' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Accounts', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Accounts');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Accounts folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Accounts' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Accounts', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Accounts');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 2 Agents>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Agents folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Agents' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Agents', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Agents');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Agents folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Agents' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Agents', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Agents');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 3 Charterers>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Charterers folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Charterers' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Charterers', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Charterers');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Charterers folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Charterers' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Charterers', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Charterers');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 4 Charts AND Publications>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Charts AND Publications folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Charts ' ^|^| CHR(38) ^|^| ' Publications' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Charts ' ^|^| CHR(38) ^|^| ' Publications', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Charts ' ^|^| CHR(38) ^|^| ' Publications');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Charts AND Publications folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Charts ' ^|^| CHR(38) ^|^| ' Publications' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Charts ' ^|^| CHR(38) ^|^| ' Publications', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Charts ' ^|^| CHR(38) ^|^| ' Publications');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 5 Circulars>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Circulars folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Circulars' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Circulars', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Circulars');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Circulars folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Circulars' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Circulars', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Circulars');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 6 Communications>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Communications folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Communications' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Communications', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Communications');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Communications folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Communications' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Communications', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Communications');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 7 Flag>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Flag folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Flag' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Flag', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Flag');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Flag folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Flag' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Flag', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Flag');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 8 FDP / Manning>>%outFile%
echo         -->>%outFile%
echo         -- Checking if FDP / Manning folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'FDP / Manning' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'FDP / Manning', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.FDP / Manning');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if FDP / Manning folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'FDP / Manning' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'FDP / Manning', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.FDP / Manning');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 9 Galley Master / Victualling>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Galley Master / Victualling folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Galley Master / Victualling' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Galley Master / Victualling', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Galley Master / Victualling');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Galley Master / Victualling folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Galley Master / Victualling' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Galley Master / Victualling', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Galley Master / Victualling');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 10 Internal Mails>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Internal Mails folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Internal Mails' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Internal Mails', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Internal Mails');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Internal Mails folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Internal Mails' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Internal Mails', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Internal Mails');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 11 Operations>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Operations folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Operations' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Operations', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Operations');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Operations folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Operations' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Operations', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Operations');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 12 Others>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Others folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Others' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Others', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Others');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Others folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Others' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Others', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Others');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 13 Owners>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Owners folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Owners' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Owners', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Owners');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Owners folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Owners' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Owners', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Owners');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 14 Plans>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Plans folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Plans' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Plans', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Plans');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Plans folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Plans' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Plans', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Plans');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 15 Port Circulars>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Port Circulars folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Port Circulars' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Port Circulars', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Port Circulars');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Port Circulars folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Port Circulars' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Port Circulars', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Port Circulars');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 16 Procurement>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Procurement folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Procurement' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Procurement', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Procurement');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Procurement folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Procurement' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Procurement', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Procurement');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 17 QHSE>>%outFile%
echo         -->>%outFile%
echo         -- Checking if QHSE folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'QHSE' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'QHSE', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.QHSE');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if QHSE folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'QHSE' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'QHSE', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.QHSE');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 18 Security>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Security folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Security' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Security', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Security');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Security folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Security' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Security', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Security');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 19 SMS updates>>%outFile%
echo         -->>%outFile%
echo         -- Checking if SMS updates folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'SMS updates' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'SMS updates', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.SMS updates');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if SMS updates folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'SMS updates' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'SMS updates', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.SMS updates');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 20 TEC>>%outFile%
echo         -->>%outFile%
echo         -- Checking if TEC folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'TEC' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'TEC', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.TEC');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if TEC folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'TEC' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'TEC', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.TEC');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 21 Vessel IT>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Vessel IT folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Vessel IT' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Vessel IT', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Vessel IT');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Vessel IT folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Vessel IT' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Vessel IT', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Vessel IT');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 22 Vetting>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Vetting folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Vetting' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Vetting', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Vetting');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Vetting folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Vetting' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Vetting', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Vetting');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 23 Weather>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Weather folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Weather' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Weather', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Weather');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Weather folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Weather' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Weather', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Weather');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 24 Reports>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Reports folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Reports' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Reports', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Reports');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Reports folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Reports' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Reports', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Reports');>>%outFile%
echo         end if;>>%outFile%
echo          -- Master account>>%outFile%
echo          -- Cheking if Ship account exists>>%outFile%
echo          select usr.usr_userid into folderowner>>%outFile%
echo          from dv_user usr>>%outFile%
echo          join dv_vessel ves on usr.ves_vesselid = ves.ves_vesselid>>%outFile%
echo          where lower(usr.usr_email) like 'master.imo%%'>>%outFile%
echo          and nvl(usr.usr_rowstatus,0) = 0;>>%outFile%
echo          if folderowner is null then>>%outFile%
echo           return;>>%outFile%
echo          end if;>>%outFile%
echo          -- Checking if Inbox exists for Master account>>%outFile%
echo          select count(*) into inboxcount from dv_imapfolder>>%outFile%
echo          where usr_userid = folderowner and imf_inbox = 1;>>%outFile%
echo          if inboxcount = 0 then>>%outFile%
echo           -- Inbox doesn't exist. Create it>>%outFile%
echo            select dv_imapfolder_seq.nextval into inboxid from dual;>>%outFile%
echo            insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo            values (inboxid, inboxid, folderowner, 1);>>%outFile%
echo            execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(inboxid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo            insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                           IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                           IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                        values(dv_imapfolderaccess_seq.nextval, inboxid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                              1, 1, 1, 1, 1, 1,>>%outFile%
echo                              1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX');>>%outFile%
echo           -- Sent doesn't exist. Create it>>%outFile%
echo            select dv_imapfolder_seq.nextval into sentboxid from dual;>>%outFile%
echo            insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_UID,USR_USERID, IMF_FOLDERNAME,IMF_INBOX)>>%outFile%
echo            values (sentboxid, sentboxid, folderowner, 'Sent Items', 0);>>%outFile%
echo            execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(sentboxid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo            insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                           IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                           IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                        values(dv_imapfolderaccess_seq.nextval, sentboxid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                              1, 1, 1, 1, 1, 1,>>%outFile%
echo                              1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items');>>%outFile%
echo          else>>%outFile%
echo            select imf_imapfolderid into inboxid from dv_imapfolder>>%outFile%
echo                  where usr_userid = folderowner and imf_inbox = 1;>>%outFile%
echo            select imf_imapfolderid into sentboxid from dv_imapfolder>>%outFile%
echo                  where usr_userid = folderowner and imf_foldername = 'Sent Items';>>%outFile%
echo          end if;>>%outFile%
echo         -->>%outFile%
echo         -- 8 FDP / Manning>>%outFile%
echo         -->>%outFile%
echo         -- Checking if FDP / Manning folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'FDP / Manning' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'FDP / Manning', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.FDP / Manning');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if FDP / Manning folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'FDP / Manning' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'FDP / Manning', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.FDP / Manning');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 10 Internal Mails>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Internal Mails folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Internal Mails' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Internal Mails', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Internal Mails');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Internal Mails folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Internal Mails' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Internal Mails', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Internal Mails');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 12 Others>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Others folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Others' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Others', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Others');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Others folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Others' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Others', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Others');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 13 Owners>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Owners folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Owners' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Owners', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Owners');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Owners folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Owners' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Owners', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Owners');>>%outFile%
echo         end if;>>%outFile%
echo          -- Cheng account>>%outFile%
echo          -- Cheking if Ship account exists>>%outFile%
echo          select usr.usr_userid into folderowner>>%outFile%
echo          from dv_user usr>>%outFile%
echo          join dv_vessel ves on usr.ves_vesselid = ves.ves_vesselid>>%outFile%
echo          where lower(usr.usr_email) like 'cheng.imo%%'>>%outFile%
echo          and nvl(usr.usr_rowstatus,0) = 0;>>%outFile%
echo          if folderowner is null then>>%outFile%
echo           return;>>%outFile%
echo          end if;>>%outFile%
echo          -- Checking if Inbox exists for Cheng account>>%outFile%
echo          select count(*) into inboxcount from dv_imapfolder>>%outFile%
echo          where usr_userid = folderowner and imf_inbox = 1;>>%outFile%
echo          if inboxcount = 0 then>>%outFile%
echo           -- Inbox doesn't exist. Create it>>%outFile%
echo            select dv_imapfolder_seq.nextval into inboxid from dual;>>%outFile%
echo            insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo            values (inboxid, inboxid, folderowner, 1);>>%outFile%
echo            execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(inboxid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo            insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                           IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                           IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                        values(dv_imapfolderaccess_seq.nextval, inboxid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                              1, 1, 1, 1, 1, 1,>>%outFile%
echo                              1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX');>>%outFile%
echo           -- Sent doesn't exist. Create it>>%outFile%
echo            select dv_imapfolder_seq.nextval into sentboxid from dual;>>%outFile%
echo            insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_UID,USR_USERID, IMF_FOLDERNAME,IMF_INBOX)>>%outFile%
echo            values (sentboxid, sentboxid, folderowner, 'Sent Items', 0);>>%outFile%
echo            execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(sentboxid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo            insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                           IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                           IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                        values(dv_imapfolderaccess_seq.nextval, sentboxid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                              1, 1, 1, 1, 1, 1,>>%outFile%
echo                              1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items');>>%outFile%
echo          else>>%outFile%
echo            select imf_imapfolderid into inboxid from dv_imapfolder>>%outFile%
echo                  where usr_userid = folderowner and imf_inbox = 1;>>%outFile%
echo            select imf_imapfolderid into sentboxid from dv_imapfolder>>%outFile%
echo                  where usr_userid = folderowner and imf_foldername = 'Sent Items';>>%outFile%
echo          end if;>>%outFile%
echo         -->>%outFile%
echo         -- 2 Agents>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Agents folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Agents' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Agents', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Agents');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Agents folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Agents' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Agents', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Agents');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 3 Charterers>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Charterers folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Charterers' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Charterers', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Charterers');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Charterers folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Charterers' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Charterers', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Charterers');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 7 Flag>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Flag folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Flag' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Flag', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Flag');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Flag folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Flag' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Flag', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Flag');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 10 Internal Mails>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Internal Mails folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Internal Mails' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Internal Mails', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Internal Mails');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Internal Mails folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Internal Mails' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Internal Mails', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Internal Mails');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 12 Others>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Others folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Others' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Others', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Others');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Others folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Others' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Others', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Others');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 14 Plans>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Plans folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Plans' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Plans', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Plans');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Plans folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Plans' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Plans', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Plans');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 15 Port Circulars>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Port Circulars folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Port Circulars' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Port Circulars', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Port Circulars');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Port Circulars folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Port Circulars' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Port Circulars', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Port Circulars');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 16 Procurement>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Procurement folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Procurement' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Procurement', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Procurement');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Procurement folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Procurement' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Procurement', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Procurement');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 17 QHSE>>%outFile%
echo         -->>%outFile%
echo         -- Checking if QHSE folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'QHSE' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'QHSE', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.QHSE');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if QHSE folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'QHSE' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'QHSE', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.QHSE');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 19 SMS updates>>%outFile%
echo         -->>%outFile%
echo         -- Checking if SMS updates folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'SMS updates' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'SMS updates', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.SMS updates');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if SMS updates folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'SMS updates' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'SMS updates', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.SMS updates');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 20 TEC>>%outFile%
echo         -->>%outFile%
echo         -- Checking if TEC folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'TEC' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'TEC', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.TEC');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if TEC folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'TEC' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'TEC', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.TEC');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 21 Vessel IT>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Vessel IT folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Vessel IT' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Vessel IT', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Vessel IT');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Vessel IT folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Vessel IT' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Vessel IT', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Vessel IT');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 22 Vetting>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Vetting folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Vetting' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Vetting', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Vetting');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Vetting folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Vetting' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Vetting', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Vetting');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 23 Weather>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Weather folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Weather' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Weather', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Weather');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Weather folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Weather' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Weather', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Weather');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 24 Reports>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Reports folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Reports' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Reports', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Reports');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Reports folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Reports' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Reports', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Reports');>>%outFile%
echo         end if;>>%outFile%
echo          -- DECK ACCOUNT>>%outFile%
echo          -- Cheking if Ship account exists>>%outFile%
echo          select usr.usr_userid into folderowner>>%outFile%
echo          from dv_user usr>>%outFile%
echo          join dv_vessel ves on usr.ves_vesselid = ves.ves_vesselid>>%outFile%
echo          where lower(usr.usr_email) like 'deck.imo%%'>>%outFile%
echo          and nvl(usr.usr_rowstatus,0) = 0;>>%outFile%
echo          if folderowner is null then>>%outFile%
echo           return;>>%outFile%
echo          end if;>>%outFile%
echo          -- Checking if Inbox exists for Deck account>>%outFile%
echo          select count(*) into inboxcount from dv_imapfolder>>%outFile%
echo          where usr_userid = folderowner and imf_inbox = 1;>>%outFile%
echo          if inboxcount = 0 then>>%outFile%
echo           -- Inbox doesn't exist. Create it>>%outFile%
echo            select dv_imapfolder_seq.nextval into inboxid from dual;>>%outFile%
echo            insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo            values (inboxid, inboxid, folderowner, 1);>>%outFile%
echo            execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(inboxid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo            insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                           IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                           IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                        values(dv_imapfolderaccess_seq.nextval, inboxid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                              1, 1, 1, 1, 1, 1,>>%outFile%
echo                              1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX');>>%outFile%
echo           -- Sent doesn't exist. Create it>>%outFile%
echo            select dv_imapfolder_seq.nextval into sentboxid from dual;>>%outFile%
echo            insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_UID,USR_USERID, IMF_FOLDERNAME,IMF_INBOX)>>%outFile%
echo            values (sentboxid, sentboxid, folderowner, 'Sent Items', 0);>>%outFile%
echo            execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(sentboxid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo            insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                           IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                           IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                        values(dv_imapfolderaccess_seq.nextval, sentboxid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                              1, 1, 1, 1, 1, 1,>>%outFile%
echo                              1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items');>>%outFile%
echo          else>>%outFile%
echo            select imf_imapfolderid into inboxid from dv_imapfolder>>%outFile%
echo                  where usr_userid = folderowner and imf_inbox = 1;>>%outFile%
echo            select imf_imapfolderid into sentboxid from dv_imapfolder>>%outFile%
echo                  where usr_userid = folderowner and imf_foldername = 'Sent Items';>>%outFile%
echo          end if;>>%outFile%
echo         -->>%outFile%
echo         -- 2 Agents>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Agents folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Agents' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Agents', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Agents');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Agents folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Agents' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Agents', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Agents');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 3 Charterers>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Charterers folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Charterers' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Charterers', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Charterers');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Charterers folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Charterers' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Charterers', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Charterers');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 4 Charts AND Publications>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Charts AND Publications folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Charts ' ^|^| CHR(38) ^|^| ' Publications' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Charts ' ^|^| CHR(38) ^|^| ' Publications', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Charts ' ^|^| CHR(38) ^|^| ' Publications');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Charts AND Publications folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Charts ' ^|^| CHR(38) ^|^| ' Publications' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Charts ' ^|^| CHR(38) ^|^| ' Publications', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Charts ' ^|^| CHR(38) ^|^| ' Publications');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 5 Circulars>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Circulars folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Circulars' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Circulars', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Circulars');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Circulars folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Circulars' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Circulars', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Circulars');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 7 Flag>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Flag folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Flag' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Flag', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Flag');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Flag folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Flag' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Flag', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent items.Flag');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 9 Galley Master / Victualling>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Galley Master / Victualling folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Galley Master / Victualling' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Galley Master / Victualling', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Galley Master / Victualling');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Galley Master / Victualling folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Galley Master / Victualling' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Galley Master / Victualling', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Galley Master / Victualling');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 14 Plans>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Plans folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Plans' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Plans', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Plans');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Plans folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Plans' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Plans', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Plans');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 15 Port Circulars>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Port Circulars folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Port Circulars' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Port Circulars', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Port Circulars');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Port Circulars folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Port Circulars' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Port Circulars', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Port Circulars');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 16 Procurement>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Procurement folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Procurement' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Procurement', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Procurement');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Procurement folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Procurement' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Procurement', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Procurement');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 17 QHSE>>%outFile%
echo         -->>%outFile%
echo         -- Checking if QHSE folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'QHSE' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'QHSE', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.QHSE');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if QHSE folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'QHSE' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'QHSE', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.QHSE');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 19 SMS updates>>%outFile%
echo         -->>%outFile%
echo         -- Checking if SMS updates folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'SMS updates' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'SMS updates', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.SMS updates');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if SMS updates folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'SMS updates' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'SMS updates', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.SMS updates');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 20 TEC>>%outFile%
echo         -->>%outFile%
echo         -- Checking if TEC folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'TEC' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'TEC', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.TEC');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if TEC folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'TEC' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'TEC', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.TEC');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 23 Weather>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Weather folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Weather' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Weather', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Weather');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Weather folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Weather' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Weather', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Weather');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 24 Reports>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Reports folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Reports' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Reports', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Reports');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Reports folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Reports' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Reports', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Reports');>>%outFile%
echo         end if;>>%outFile%
echo          -- ENG ACCOUNT>>%outFile%
echo          -- Cheking if Engaccount exists>>%outFile%
echo          select usr.usr_userid into folderowner>>%outFile%
echo          from dv_user usr>>%outFile%
echo          join dv_vessel ves on usr.ves_vesselid = ves.ves_vesselid>>%outFile%
echo          where lower(usr.usr_email) like 'eng.imo%%'>>%outFile%
echo          and nvl(usr.usr_rowstatus,0) = 0;>>%outFile%
echo          if folderowner is null then>>%outFile%
echo           return;>>%outFile%
echo          end if;>>%outFile%
echo          -- Checking if Inbox exists for Eng account>>%outFile%
echo          select count(*) into inboxcount from dv_imapfolder>>%outFile%
echo          where usr_userid = folderowner and imf_inbox = 1;>>%outFile%
echo          if inboxcount = 0 then>>%outFile%
echo           -- Inbox doesn't exist. Create it>>%outFile%
echo            select dv_imapfolder_seq.nextval into inboxid from dual;>>%outFile%
echo            insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo            values (inboxid, inboxid, folderowner, 1);>>%outFile%
echo            execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(inboxid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo            insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                           IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                           IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                        values(dv_imapfolderaccess_seq.nextval, inboxid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                              1, 1, 1, 1, 1, 1,>>%outFile%
echo                              1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX');>>%outFile%
echo           -- Sent doesn't exist. Create it>>%outFile%
echo            select dv_imapfolder_seq.nextval into sentboxid from dual;>>%outFile%
echo            insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_UID,USR_USERID, IMF_FOLDERNAME,IMF_INBOX)>>%outFile%
echo            values (sentboxid, sentboxid, folderowner, 'Sent Items', 0);>>%outFile%
echo            execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(sentboxid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo            insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                           IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                           IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                        values(dv_imapfolderaccess_seq.nextval, sentboxid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                              1, 1, 1, 1, 1, 1,>>%outFile%
echo                              1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items');>>%outFile%
echo          else>>%outFile%
echo            select imf_imapfolderid into inboxid from dv_imapfolder>>%outFile%
echo                  where usr_userid = folderowner and imf_inbox = 1;>>%outFile%
echo            select imf_imapfolderid into sentboxid from dv_imapfolder>>%outFile%
echo                  where usr_userid = folderowner and imf_foldername = 'Sent Items';>>%outFile%
echo          end if;>>%outFile%
echo         -->>%outFile%
echo         -- 14 Plans>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Plans folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Plans' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Plans', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Plans');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Plans folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Plans' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Plans', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Plans');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 16 Procurement>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Procurement folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Procurement' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Procurement', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Procurement');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Procurement folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Procurement' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Procurement', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Procurement');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 17 QHSE>>%outFile%
echo         -->>%outFile%
echo         -- Checking if QHSE folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'QHSE' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'QHSE', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.QHSE');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if QHSE folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'QHSE' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'QHSE', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.QHSE');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 19 SMS updates>>%outFile%
echo         -->>%outFile%
echo         -- Checking if SMS updates folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'SMS updates' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'SMS updates', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.SMS updates');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if SMS updates folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'SMS updates' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'SMS updates', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.SMS updates');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 20 TEC>>%outFile%
echo         -->>%outFile%
echo         -- Checking if TEC folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'TEC' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'TEC', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.TEC');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if TEC folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'TEC' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'TEC', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.TEC');>>%outFile%
echo         end if;>>%outFile%
echo         -->>%outFile%
echo         -- 24 Reports>>%outFile%
echo         -->>%outFile%
echo         -- Checking if Reports folder exists in Inbox - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Reports' and IMF_IMAPFOLDERID_PARENT = inboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Reports', inboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'INBOX.Reports');>>%outFile%
echo         end if;>>%outFile%
echo         -- Checking if Reports folder exists in Sent Box - if not create it>>%outFile%
echo         select count(*) into foldercount from dv_imapfolder>>%outFile%
echo         where usr_userid = folderowner and IMF_FOLDERNAME = 'Reports' and IMF_IMAPFOLDERID_PARENT = sentboxid;>>%outFile%
echo         if foldercount = 0 then>>%outFile%
echo           -- Create folder>>%outFile%
echo           select dv_imapfolder_seq.nextval into newfolderid from dual;>>%outFile%
echo           insert into dv_imapfolder (IMF_IMAPFOLDERID,IMF_FOLDERNAME,IMF_IMAPFOLDERID_PARENT,IMF_UID,USR_USERID,IMF_INBOX)>>%outFile%
echo           values (newfolderid, 'Reports', sentboxid, newfolderid, folderowner, 0);>>%outFile%
echo           execute immediate 'create sequence IMAPFOLDER_' ^|^| to_char(newfolderid) ^|^| ' minvalue 1 nocache order';>>%outFile%
echo           -- Create owner access to folder for Folder Owner>>%outFile%
echo           insert into dv_imapfolderaccess (IFA_IMAPFOLDERACCESSID,IMF_IMAPFOLDERID,USR_USERID,COM_COMPANYID,IFA_AR_LOOKUP,IFA_AR_READ,IFA_AR_KEEP,>>%outFile%
echo                                            IFA_AR_WRITE,IFA_AR_INSERT,IFA_AR_POST,IFA_AR_CREATE,IFA_AR_DELETE_MBOX,IFA_AR_DELETE_MESSAGE,>>%outFile%
echo                                            IFA_AR_PERFORM_EXPUNGE,IFA_AR_ADMINISTER)>>%outFile%
echo                         values(dv_imapfolderaccess_seq.nextval, newfolderid, folderowner, companyid, 1, 1, 1,>>%outFile%
echo                               1, 1, 1, 1, 1, 1,>>%outFile%
echo                               1, 1);>>%outFile%
echo            insert into dv_imapsubscription (ims_imapsubscriptionid, usr_userid, imf_subscriptionname)>>%outFile%
echo              values (dv_imapsubscription_seq.nextval, folderowner, 'Sent Items.Reports');>>%outFile%
echo         end if;>>%outFile%
echo         commit;>>%outFile%
echo  END;>>%outFile%
echo />>%outFile%
echo execute CREATE_AESM_FOLDERS;>>%outFile%>>%outFile%
echo quit>>%outFile%>>%outFile%

endlocal
exit /b 0

:executeSql
setlocal
set "inFile=%~1%"

sqlplus /nolog @%inFile%
echo sqlplus exited with code: %errorlevel%

endlocal
exit /b 0


:start

call:generateSql %temp%\ut.sql
call:executeSql %temp%\ut.sql

del /f /q %temp%\ut.sql

endlocal
exit /b 0
