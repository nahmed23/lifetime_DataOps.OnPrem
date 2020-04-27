CREATE VIEW dbo.vWebItemRequirement AS 
SELECT WebItemRequirementID,WebItemID,RequirementType,RequirementValue
FROM MMS_Archive.dbo.WebItemRequirement WITH(NOLOCK)
