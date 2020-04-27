-- =============================================
-- Object:			mmsGuestCounter
-- Author:			Ruslan Condratiuc	
-- Create date: 	7/28/2008
-- Description:		Returns summary by club of guest privilege use for a particular month
-- Parameters:      Start Visit Date, End Visit Date, Club or List of Clubs
-- Modified Date:	
--					
-- 
-- EXEC dbo.mmsGuestCounter '07/1/08', '07/31/08 11:59 PM', 'All'
--
-- =============================================

CREATE  PROC [dbo].[mmsGuestCounter] 
(
	@StartVisitDate SMALLDATETIME,
	@EndVisitDate SMALLDATETIME,
	@ClubList VARCHAR(8000)	
)
AS
BEGIN


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
	

	CREATE TABLE #ClubLevel (ClubID int, ClubLevel varchar(15), ClubLevelOrder int)
	CREATE TABLE #MonthlyGuestCount (MonthlyGuestCount int, ClubID int, ClubName varchar(100), ClubLevel varchar(50), ClubLevelOrder int)
	CREATE TABLE #TotalNonTerminatedMemberships (NonTermMembershipsCount int, ClubID int)
	CREATE TABLE #YTDGuestCount (YTDGuestCount int, ClubID int)
	CREATE TABLE #MonthlyGuestCount_Single (MonthlyGuestCount_Single int, ClubID int)
	CREATE TABLE #MonthlyGuestCount_Couple (MonthlyGuestCount_Couple int, ClubID int)
	CREATE TABLE #MonthlyGuestCount_Family (MonthlyGuestCount_Family int, ClubID int)
	CREATE TABLE #Memberships_1GuestYear (Memberships_1GuestYear int, ClubID int)
	--CREATE TABLE #Memberships_1GuestMonth (Memberships_1GuestMonth int, ClubID int)
	CREATE TABLE #MonthGuestUsage (MonthGuestUsage25 int, MonthGuestUsage50 int, MonthGuestUsage75 int, MonthGuestUsage100 int, ClubID int, MembershipCountMGU int)
	CREATE TABLE #YearGuestUsage (YearGuestUsage25 int, YearGuestUsage50 int, YearGuestUsage75 int, YearGuestUsage100 int, ClubID int, MembershipCountYGU int)


-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

	-- Club Level
	INSERT INTO #ClubLevel (ClubID, ClubLevel, ClubLevelOrder)
	SELECT c.ClubID, vmtg.Description --,c.CheckInGroupLevel
	,CASE vmtg.Description 
	 WHEN 'Bronze' THEN 1 
	 WHEN 'Gold' THEN 2 
	 WHEN 'Platinum' THEN 3 
	 WHEN 'Onyx' THEN 4 END ClubLevelOrder
	FROM vClub c
	JOIN (SELECT cp.ClubID, MIN (mt.ValMembershipTypeGroupID) ValMembershipTypeGroupID
			FROM vMembershipType mt
			JOIN vClubProduct cp
			ON cp.ProductID = mt.ProductID
			JOIN vClub c
				ON c.ClubID = cp.ClubID
			WHERE cp.SoldInPK = 1
				AND mt.ValCheckInGroupID >= c.CheckInGroupLevel
			GROUP BY cp.ClubID) types
	  ON types.ClubID = c.ClubID
	JOIN vValMembershipTypeGroup vmtg
	  ON vmtg.ValMembershipTypeGroupID = Types.ValMembershipTypeGroupID
	WHERE c.DisplayUIFlag = 1
	ORDER BY c.ClubID

	--Monthly Guest Count
	INSERT INTO #MonthlyGuestCount (MonthlyGuestCount , ClubID, ClubName, ClubLevel, ClubLevelOrder)
	SELECT 
		count(GV.GuestID), GV.ClubID, C.ClubName, tCL.ClubLevel AS ClubLevel, tCL.ClubLevelOrder AS ClubLevelOrder
	FROM vGuestVisit GV
	JOIN vClub C ON C.ClubID = GV.ClubID
	JOIN vValCheckInGroup vCIG ON vCIG.ValCheckInGroupID = C.CheckInGroupLevel
	JOIN #Clubs tC ON tC.ClubID = C.ClubID
	JOIN #ClubLevel tCL ON tCL.ClubID = C.ClubID
	WHERE 
	GV.VisitDateTime between @StartVisitDate and @EndVisitDate
	GROUP BY GV.ClubID, C.ClubName, tCL.ClubLevel, tCL.ClubLevelOrder

	-- Total Non-Terminated Memberships at the club
	INSERT INTO #TotalNonTerminatedMemberships (NonTermMembershipsCount, ClubID )
	SELECT  
		count(*), M.clubid
	FROM vMembership M
	JOIN vClub C ON C.ClubID = M.ClubID
	JOIN #Clubs tC ON tC.ClubID = C.ClubID
	WHERE 
	M.CreatedDateTime <= @EndVisitDate and (M.ExpirationDate > @EndVisitDate or M.ExpirationDate is null) 
	GROUP BY M.ClubId


	-- Year to Date Guest count 
	INSERT INTO #YTDGuestCount (YTDGuestCount, ClubID)
	SELECT 
		count(GV.GuestID), GV.ClubID
	FROM vGuestVisit GV
	JOIN vClub C ON C.ClubID = GV.ClubID
	JOIN #Clubs tC ON tC.ClubID = C.ClubID
	WHERE 
	GV.VisitDateTime between '01/01/'+ convert(varchar,year(@StartVisitDate)) and @EndVisitDate
	GROUP BY GV.ClubID
	
	-- Monthly Guest Count on Single Memberships  
	INSERT INTO #MonthlyGuestCount_Single (MonthlyGuestCount_Single, ClubID)
	SELECT count(GV.MemberID) MonthlyGuestCount_Single, GV.ClubID
	FROM vGuestVisit GV 
		JOIN vMember M ON M.MemberID = GV.MemberID
		JOIN vMembership MS ON MS.MembershipID = M.MembershipID
		JOIN vMembershipType MT ON MT.MembershipTypeID = MS.MembershipTypeID
		JOIN vValMembershipTypeFamilyStatus MTFS ON MTFS.ValMembershipTypeFamilyStatusID = MT.ValMembershipTypeFamilyStatusID
		JOIN vClub C ON C.ClubID = GV.ClubID
		JOIN #Clubs tC ON tC.ClubID = C.ClubID
	WHERE 
		GV.VisitDateTime BETWEEN @StartVisitDate AND @EndVisitDate AND
		MTFS.Description = 'Single Membership Type'
	GROUP BY GV.ClubID

	--Monthly Guest Count on Couple Memberships 
	INSERT INTO #MonthlyGuestCount_Couple (MonthlyGuestCount_Couple, ClubID)
	SELECT count(GV.MemberID) MonthlyGuestCount_Couple, GV.ClubID
	FROM vGuestVisit GV 
		JOIN vMember M ON M.MemberID = GV.MemberID
		JOIN vMembership MS ON MS.MembershipID = M.MembershipID
		JOIN vMembershipType MT ON MT.MembershipTypeID = MS.MembershipTypeID
		JOIN vValMembershipTypeFamilyStatus MTFS ON MTFS.ValMembershipTypeFamilyStatusID = MT.ValMembershipTypeFamilyStatusID
		JOIN vClub C ON C.ClubID = GV.ClubID
		JOIN #Clubs tC ON tC.ClubID = C.ClubID
	WHERE 
		GV.VisitDateTime BETWEEN @StartVisitDate AND @EndVisitDate AND
		MTFS.Description = 'Couple Membership Type'
	GROUP BY GV.ClubID

	-- Monthly Guest Count on Family Memberships
	INSERT INTO #MonthlyGuestCount_Family (MonthlyGuestCount_Family, ClubID)
	SELECT count(GV.MemberID) MonthlyGuestCount_Family, GV.ClubID
	FROM vGuestVisit GV 
		JOIN vMember M ON M.MemberID = GV.MemberID
		JOIN vMembership MS ON MS.MembershipID = M.MembershipID
		JOIN vMembershipType MT ON MT.MembershipTypeID = MS.MembershipTypeID
		JOIN vValMembershipTypeFamilyStatus MTFS ON MTFS.ValMembershipTypeFamilyStatusID = MT.ValMembershipTypeFamilyStatusID
		JOIN vClub C ON C.ClubID = GV.ClubID
		JOIN #Clubs tC ON tC.ClubID = C.ClubID
	WHERE 
		GV.VisitDateTime BETWEEN @StartVisitDate AND @EndVisitDate AND
		MTFS.Description = 'Family Membership Type'
	GROUP BY GV.ClubID

	-- Number of Memberships that brought at least 1 guest during the year
	INSERT INTO #Memberships_1GuestYear (Memberships_1GuestYear, ClubID)
	SELECT 
		count(distinct m.membershipid), GV.ClubID
	FROM vGuestVisit GV 
		JOIN vMember M ON M.MemberID = GV.MemberID
		JOIN vMembership MS ON MS.MembershipID = M.MembershipID
		JOIN vClub C ON C.ClubID = GV.ClubID
		JOIN #Clubs tC ON tC.ClubID = C.ClubID
	WHERE 
	GV.VisitDateTime between '01/01/'+ convert(varchar,year(@StartVisitDate)) and @EndVisitDate
	GROUP BY GV.ClubID

	-- Number of Memberships that brought at least 1 guest during the month
/*
	INSERT INTO #Memberships_1GuestMonth (Memberships_1GuestMonth, ClubID)
	SELECT 
		count(distinct m.membershipid), GV.ClubID
	FROM vGuestVisit GV 
		JOIN vMember M ON M.MemberID = GV.MemberID
		JOIN vMembership MS ON MS.MembershipID = M.MembershipID
		JOIN vClub C ON C.ClubID = GV.ClubID
		JOIN #Clubs tC ON tC.ClubName = C.ClubName
	WHERE 
	GV.VisitDateTime between @StartVisitDate and @EndVisitDate
	GROUP BY GV.ClubID
*/
	-- Number of pre-2/1/08 Memberships at the club who have reached 25/50/75/100% 
	-- of their allowable guest usage for the month.
	INSERT INTO #MonthGuestUsage (ClubID, MonthGuestUsage25, MonthGuestUsage50, MonthGuestUsage75, MonthGuestUsage100, MembershipCountMGU)
	SELECT 
	ClubID
	,SUM(case WHEN NumberofGuests <> 0 THEN	case when GuestUsage*1.00/NumberofGuests*100 between 25 and 49 	THEN 1 	ELSE 0 	END ELSE 0 END)  GuestUsage25
	,SUM(case WHEN NumberofGuests <> 0 THEN	case when GuestUsage*1.00/NumberofGuests*100 between 50 and 74 	THEN 1 	ELSE 0 	END ELSE 0 END)  GuestUsage50
	,SUM(case WHEN NumberofGuests <> 0 THEN	case when GuestUsage*1.00/NumberofGuests*100 between 75 and 99 	THEN 1 	ELSE 0 	END ELSE 0 END)  GuestUsage75
	,SUM(case WHEN NumberofGuests <> 0 THEN	case when GuestUsage*1.00/NumberofGuests*100 >= 100	THEN 1 	ELSE 0 	END ELSE 0 END)  GuestUsage100
	,count(membershipid) AS MembershipCountMGU
	FROM
	( 
		SELECT 
			count(gv.memberid) as GuestUsage, GPR.NumberOfGuests as NumberOfGuests, m.membershipid as MembershipID, GV.ClubID as ClubID
		FROM vGuestVisit GV 
			JOIN vMember M ON M.MemberID = GV.MemberID
			JOIN vMembership MS ON MS.MembershipID = M.MembershipID
			JOIN vMembershipType MT ON MT.MembershipTypeID = MS.MembershipTypeID  
			JOIN vGuestPrivilegeRule GPR ON
				( MT.ValCheckInGroupID BETWEEN GPR.LowClubAccessLevel AND GPR.HighClubAccessLevel ) 
				  AND ( ISNULL( MS.CreatedDateTime, '01-01-1999' ) BETWEEN GPR.MembershipStartDate AND GPR.MembershipEndDate )
				AND GPR.ValPeriodTypeID = 1 -- allowed guests per month
			JOIN vClub C ON C.ClubID = GV.ClubID
			JOIN #Clubs tC ON tC.ClubID = C.ClubID
		WHERE
			GV.VisitDateTime between @StartVisitDate and @EndVisitDate
		GROUP BY GPR.NumberOfGuests, m.membershipid, gv.ClubID
	) G1
	group by clubid
	

	-- Report-2.10	Number of post-2/1/08 Memberships at the club who have reached 25/50/75/100% 
	-- of their allowable guest usage for the year.
	INSERT INTO #YearGuestUsage (ClubID, YearGuestUsage25, YearGuestUsage50, YearGuestUsage75, YearGuestUsage100, MembershipCountYGU)
	SELECT 
	ClubID
	,SUM(case WHEN NumberofGuests <> 0 THEN	case when GuestUsage*1.00/NumberofGuests*100 between 25 and 49 	THEN 1 	ELSE 0 	END ELSE 0 END)  GuestUsage25
	,SUM(case WHEN NumberofGuests <> 0 THEN	case when GuestUsage*1.00/NumberofGuests*100 between 50 and 74 	THEN 1 	ELSE 0 	END ELSE 0 END)  GuestUsage50
	,SUM(case WHEN NumberofGuests <> 0 THEN	case when GuestUsage*1.00/NumberofGuests*100 between 75 and 99 	THEN 1 	ELSE 0 	END ELSE 0 END)  GuestUsage75
	,SUM(case WHEN NumberofGuests <> 0 THEN	case when GuestUsage*1.00/NumberofGuests*100 >= 100	THEN 1 	ELSE 0 	END ELSE 0 END)  GuestUsage100
	,count(membershipid) AS MembershipCountYGU
	FROM
	( 
		SELECT 
			count(gv.memberid) as GuestUsage, GPR.NumberOfGuests as NumberOfGuests, m.membershipid as MembershipID, GV.ClubID as ClubID
		FROM vGuestVisit GV 
			JOIN vMember M ON M.MemberID = GV.MemberID
			JOIN vMembership MS ON MS.MembershipID = M.MembershipID
			JOIN vMembershipType MT ON MT.MembershipTypeID = MS.MembershipTypeID  
			JOIN vGuestPrivilegeRule GPR ON
				( MT.ValCheckInGroupID BETWEEN GPR.LowClubAccessLevel AND GPR.HighClubAccessLevel ) 
				  AND ( ISNULL( MS.CreatedDateTime, '01-01-1999' ) BETWEEN GPR.MembershipStartDate AND GPR.MembershipEndDate )
				AND GPR.ValPeriodTypeID = 2 -- allowed guests per year
			JOIN vClub C ON C.ClubID = GV.ClubID
			JOIN #Clubs tC ON tC.ClubID = C.ClubID
		WHERE 
			GV.VisitDateTime BETWEEN '01/01/'+ convert(varchar,year(@StartVisitDate)) AND @EndVisitDate
		GROUP BY GPR.NumberOfGuests, M.Membershipid, GV.ClubID
	) G1
	group by clubid


	SELECT 
		MGC.ClubID, 
		MGC.ClubName, ClubLevelOrder,

        ISNULL(MonthlyGuestCount,0) AS MonthlyGuestCount, 
		ISNULL(NonTermMembershipsCount,0) AS NonTermMembershipsCount,
		ISNULL(case WHEN NonTermMembershipsCount <> 0 THEN	MonthlyGuestCount*1.00/NonTermMembershipsCount ELSE 0 END ,0) AS MonthlyPercentageMembershps,

		 
        ISNULL(YTDGuestCount,0) AS YTDGuestCount,
		ISNULL(case WHEN NonTermMembershipsCount <> 0 THEN	YTDGuestCount*1.00/NonTermMembershipsCount ELSE 0 END ,0) AS YTDPercentageMembershps,
		 
		 ISNULL(MonthlyGuestCount_Single,0) AS MonthlyGuestCount_Single,
		 ISNULL(MonthlyGuestCount_Couple,0) AS MonthlyGuestCount_Couple,
		 ISNULL(MonthlyGuestCount_Family,0) AS MonthlyGuestCount_Family,

		 ISNULL(case WHEN MonthlyGuestCount <> 0 THEN MonthlyGuestCount_Single*1.00/MonthlyGuestCount ELSE 0 END ,0) AS SinglePercentageTotal,
		 ISNULL(case WHEN MonthlyGuestCount <> 0 THEN MonthlyGuestCount_Couple*1.00/MonthlyGuestCount ELSE 0 END ,0) AS CouplePercentageTotal,
		 ISNULL(case WHEN MonthlyGuestCount <> 0 THEN MonthlyGuestCount_Family*1.00/MonthlyGuestCount ELSE 0 END ,0) AS FamilyPercentageTotal,
		 
		 ISNULL(Memberships_1GuestYear,0) AS Memberships_1GuestYear,
		 ISNULL(case WHEN NonTermMembershipsCount <> 0 THEN Memberships_1GuestYear*1.00/NonTermMembershipsCount ELSE 0 END ,0) AS MembershipPercentageGuestUsage,

		 ISNULL(MembershipCountMGU,0) AS MembershipCountMGU,
		 ISNULL(MonthGuestUsage25,0) AS MonthGuestUsage25,
		 ISNULL(MonthGuestUsage50,0) AS MonthGuestUsage50,
		 ISNULL(MonthGuestUsage75,0) AS MonthGuestUsage75,
		 ISNULL(MonthGuestUsage100,0) AS MonthGuestUsage100,

		 ISNULL(case WHEN MembershipCountMGU <> 0 THEN MonthGuestUsage25*1.00/MembershipCountMGU ELSE 0 END ,0) AS MonthlyMaxUsage25, 
		 ISNULL(case WHEN MembershipCountMGU <> 0 THEN MonthGuestUsage50*1.00/MembershipCountMGU ELSE 0 END ,0) AS MonthlyMaxUsage50, 
		 ISNULL(case WHEN MembershipCountMGU <> 0 THEN MonthGuestUsage75*1.00/MembershipCountMGU ELSE 0 END ,0) AS MonthlyMaxUsage75, 
		 ISNULL(case WHEN MembershipCountMGU <> 0 THEN MonthGuestUsage100*1.00/MembershipCountMGU ELSE 0 END ,0) AS MonthlyMaxUsage100, 
	 
		 ISNULL(MembershipCountYGU,0) AS MembershipCountYGU, 
		 ISNULL(YearGuestUsage25,0) AS  YearGuestUsage25, 
		 ISNULL(YearGuestUsage50, 0) AS YearGuestUsage50, 
		 ISNULL(YearGuestUsage75, 0) AS YearGuestUsage75, 
		 ISNULL(YearGuestUsage100,0) AS YearGuestUsage100,

		 ISNULL(case WHEN MembershipCountYGU <> 0 THEN YearGuestUsage25*1.00/MembershipCountYGU ELSE 0 END ,0) AS YearMaxUsage25, 
		 ISNULL(case WHEN MembershipCountYGU <> 0 THEN YearGuestUsage50*1.00/MembershipCountYGU ELSE 0 END ,0) AS YearMaxUsage50, 
		 ISNULL(case WHEN MembershipCountYGU <> 0 THEN YearGuestUsage75*1.00/MembershipCountYGU ELSE 0 END ,0) AS YearMaxUsage75, 
		 ISNULL(case WHEN MembershipCountYGU <> 0 THEN YearGuestUsage100*1.00/MembershipCountYGU ELSE 0 END ,0) AS YearMaxUsage100, 
		 
		 MGC.ClubLevel,
		 @StartVisitDate AS ReportStartDate,  @EndVisitDate AS ReportEndDate
 

	FROM #MonthlyGuestCount MGC
		LEFT OUTER JOIN #TotalNonTerminatedMemberships TNTM ON TNTM.ClubID = MGC.ClubID
		LEFT OUTER JOIN #YTDGuestCount YTDGC ON YTDGC.ClubID = MGC.ClubID
		LEFT OUTER JOIN #MonthlyGuestCount_Single MGCS ON MGCS.ClubID = MGC.ClubID
		LEFT OUTER JOIN #MonthlyGuestCount_Couple MGCC ON MGCC.ClubID = MGC.ClubID
		LEFT OUTER JOIN #MonthlyGuestCount_Family MGCF ON MGCF.ClubID = MGC.ClubID
		LEFT OUTER JOIN #Memberships_1GuestYear M1GY ON M1GY.ClubID = MGC.ClubID
		LEFT OUTER JOIN #MonthGuestUsage MGU ON MGU.ClubID = MGC.ClubID
		LEFT OUTER JOIN #YearGuestUsage YGU ON YGU.ClubID = MGC.ClubID
		--LEFT OUTER JOIN #Memberships_1GuestMonth M1GM ON M1GM.ClubID = MGC.ClubID

	
	DROP TABLE #ClubLevel 
	DROP TABLE #MonthlyGuestCount 
	DROP TABLE #TotalNonTerminatedMemberships 
	DROP TABLE #YTDGuestCount 
	DROP TABLE #MonthlyGuestCount_Single 
	DROP TABLE #MonthlyGuestCount_Couple 
	DROP TABLE #MonthlyGuestCount_Family 
	DROP TABLE #Memberships_1GuestYear 
	--DROP TABLE #Memberships_1GuestMonth 
	DROP TABLE #MonthGuestUsage 
	DROP TABLE #YearGuestUsage 
	DROP table #Clubs
	DROP table #tmpList


	-- Report Logging
	  UPDATE HyperionReportLog
	  SET EndDateTime = getdate()
	  WHERE ReportLogID = @Identity
END

