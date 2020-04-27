




CREATE PROC [dbo].[procCognos_PromptEmployeeClubRole](
              @ClubIDList VARCHAR(2000)
)
AS
BEGIN

/*
 Exec procCognos_PromptEmployeeClubRole '815'
 select * from vemployee where employeeid = 49830
 clubid = 815
 select * from vMembershipMessage where clubid =13
 select * from vclub where  clubid =166 clubname like 'corp' +'%'
*/

SET XACT_ABORT ON
SET NOCOUNT ON

CREATE TABLE #tmpList (StringField VARCHAR(20))
CREATE TABLE #Clubs (ClubID INT)
  EXEC procParseIntegerList @ClubIDList
  INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
  TRUNCATE TABLE #tmpList
  
  IF (SELECT COUNT(*) FROM #Clubs WHERE ClubID = 0) = 1  -- all clubs option selected
   BEGIN 
    TRUNCATE TABLE #Clubs  
    INSERT INTO #Clubs (ClubID) SELECT ClubID FROM vClub
   END


SELECT C.ClubName, 
       VER.Description AS RoleDescription, 
       E.EmployeeID, E.FirstName, E.LastName, 
       E.FirstName+' '+ E.LastName AS EmployeeName,
       C.ClubID, 
	   2 AS Sort_Order,
	   E.HireDate,
	   E.TerminationDate,
	   IsNull(E.TerminationDate,DATEADD(year,10,getdate())) AS NonNull_TerminationDate_forCognos
  FROM dbo.vClub C 
  JOIN #Clubs CS
       ON C.ClubID = CS.ClubID 
  JOIN dbo.vEmployee E
       ON E.ClubID = C.ClubID
  JOIN dbo.vEmployeeRole ER
       ON ER.EmployeeID = E.EmployeeID
  JOIN dbo.vValEmployeeRole VER 
       ON VER.ValEmployeeRoleID = ER.ValEmployeeRoleID

UNION 
SELECT '' AS ClubName, 
       '' AS RoleDescription, 
       E.EmployeeID, E.FirstName, E.LastName, 
       E.FirstName+' '+ E.LastName AS EmployeeName,
       C.ClubID, 
	   1 AS Sort_Order,   
	   E.HireDate,
	   E.TerminationDate,
	   IsNull(E.TerminationDate,DATEADD(year,10,getdate())) AS NonNull_TerminationDate_forCognos   			
  FROM dbo.vClub C 
  JOIN dbo.vEmployee E
       ON E.ClubID = C.ClubID
  WHERE E.EmployeeID < 0


DROP TABLE #tmpList

END





