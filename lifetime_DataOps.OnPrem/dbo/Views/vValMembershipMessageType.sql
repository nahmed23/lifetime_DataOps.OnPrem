

CREATE VIEW dbo.vValMembershipMessageType AS 
SELECT ValMembershipMessageTypeID,Description,SortOrder,AutoCloseFlag,ValMessageSeverityID,Abbreviation,EFTSingleOpenFlag
FROM MMS.dbo.ValMembershipMessageType WITH (NoLock)


