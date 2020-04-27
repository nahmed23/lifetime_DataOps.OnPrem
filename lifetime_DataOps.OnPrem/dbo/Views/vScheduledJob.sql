


CREATE VIEW dbo.vScheduledJob
AS
SELECT     ScheduledJobID, Name, ClassToRun, StartDate, EndDate, Active, ValScheduledJobTypeID, [Interval], MinuteOfHour, TimeOfDay, DayOfWeek, 
                      DayOfMonth, WeekOfMonth, LastFlag
FROM         MMS.dbo.ScheduledJob With (NOLOCK)



