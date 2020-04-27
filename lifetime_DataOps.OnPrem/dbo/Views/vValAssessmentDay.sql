CREATE VIEW dbo.vValAssessmentDay AS 
SELECT ValAssessmentDayID,Description,AssessmentDay,SortOrder,InsertedDatetime,UpdatedDateTime
FROM MMS.dbo.ValAssessmentDay WITH(NOLOCK)
