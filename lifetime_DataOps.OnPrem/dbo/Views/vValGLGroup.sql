
CREATE VIEW dbo.vValGLGroup AS 
SELECT ValGLGroupID,Description,SortOrder
FROM MMS.dbo.ValGLGroup WITH (NoLock)

