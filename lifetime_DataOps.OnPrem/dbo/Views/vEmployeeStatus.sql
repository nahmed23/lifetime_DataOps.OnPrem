
CREATE VIEW dbo.vEmployeeStatus AS
SELECT e.*, wdw.Status from vEmployee e (NOLOCK) 
INNER JOIN Integration.dbo.WorkdayWorker wdw (NOLOCK)
ON e.EmployeeID = wdw.EmployeeNumber
