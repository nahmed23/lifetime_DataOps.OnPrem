

-- =============================================
-- Object:			mmsPTInvalidSession
-- Author:			Ruslan Condratiuc	
-- Create date: 	11/13/2008
-- Description:		returns a list of PT sessions that  were checked off for members that did not check into 
--  				club that same day prior to the session checked-off time
-- Parameters:      Session Delivered Start Date, Session Delivered End Date, Club or List of Clubs, RCL Area ID List or List of RCL Area IDs
-- Modified Date:	
-- 
-- EXEC mmsPTInvalidSession '4/1/2011', '4/11/2011', '141'
-- 
-- =============================================


CREATE  PROC [dbo].[mmsPTInvalidSession] 
(
	@DeliveredDateStart SMALLDATETIME,
	@DeliveredDateeND SMALLDATETIME,
	@ClubList VARCHAR(8000)	
)
AS
BEGIN

  -- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY
  
	-- SELECTED CLUBS
	CREATE TABLE #tmpList (StringField VARCHAR(50))
	CREATE TABLE #Clubs (ClubID VARCHAR(50))
	IF @ClubList <> 'All'
		BEGIN
		  -- Parse the ClubIDs into a temp table
		  EXEC procParseIntegerList @ClubList
		  INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
		  TRUNCATE TABLE #tmpList
		END
	ELSE
		BEGIN
			INSERT INTO #Clubs (ClubID) SELECT ClubID FROM vClub
		END
	

	SELECT 
	PK.memberid AS MemberID,
	PTRCL.Description AS PTRCLAreaName, 
    C.ClubName, 
    C.ClubID, 
    C.ValPTRCLAreaID, 
    E.FirstName AS EmpFirstName, 
    E.LastName AS EmpLastName, 
    E.MiddleInt AS EmpMiddleName, 
	P.Description AS PackageSession, 
	PS.DeliveredDateTime as SessionCheckOff_Sort, 	
	Replace(Substring(convert(varchar,PS.DeliveredDateTime,100),1,6)+', '+Substring(convert(varchar,PS.DeliveredDateTime,100),8,10)+' '+Substring(convert(varchar,PS.DeliveredDateTime,100),18,2),'  ',' ') as SessionCheckOff,
	M.FirstName AS MemberFirstName, 
	M.LastName AS MemberLastName, 
	M.MiddleName AS MemberMiddleName
	  

	FROM vPackageSession PS
	INNER JOIN vPackage PK
		on PK.packageid = PS.packageid
	INNER JOIN vproduct P
		on P.productid = PK.productid
	INNER JOIN vemployee E
	  on e.employeeid = PS.deliveredemployeeid
	INNER JOIN vclub C
		on c.clubid = PS.clubid
	INNER JOIN vValPTRCLArea PTRCL
		on PTRCL.ValPTRCLAreaID = c.ValPTRCLAreaID
	INNER JOIN vmember M
		on M.memberid = PK.memberid
	INNER JOIN #Clubs tC 
		ON tC.ClubID = c.clubid
	WHERE PS.DeliveredDateTime >= @DeliveredDateStart and PS.DeliveredDateTime <= @DeliveredDateEnd
	AND PS.DeliveredDateTime <=(
		select 
		COALESCE(min(MU.UsageDateTime),'2050-12-31')
		from vMemberUsage mu where 
		-- select all records (check ins) for a given date 
		convert(datetime,convert(varchar(12),PS.DeliveredDateTime,101)) = convert(datetime,convert(varchar(12),MU.UsageDateTime,101))
		and pk.memberid = mu.memberid
	)

	DROP TABLE #tmpList 
	DROP TABLE #Clubs 
	

	-- Report Logging
	  UPDATE HyperionReportLog
	  SET EndDateTime = getdate()
	  WHERE ReportLogID = @Identity

END

