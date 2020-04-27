CREATE VIEW dbo.vEmployee AS 
SELECT EmployeeID,ClubID,ActiveStatusFlag,FirstName,LastName,MiddleInt,InsertedDateTime,MemberID,UpdatedDateTime,HireDate,TerminationDate
FROM MMS.dbo.Employee WITH(NOLOCK)
