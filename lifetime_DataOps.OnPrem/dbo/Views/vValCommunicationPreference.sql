
CREATE VIEW dbo.vValCommunicationPreference AS 
SELECT ValCommunicationPreferenceID,Description,SortOrder
FROM MMS.dbo.ValCommunicationPreference WITH (NoLock)

