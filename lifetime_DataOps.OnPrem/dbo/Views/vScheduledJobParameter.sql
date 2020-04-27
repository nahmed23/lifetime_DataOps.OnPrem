


CREATE VIEW dbo.vScheduledJobParameter
AS
SELECT     ScheduledJobParameterID, ScheduledJobID, Name, [Value]
FROM         MMS.dbo.ScheduledJobParameter With (NOLOCK)



