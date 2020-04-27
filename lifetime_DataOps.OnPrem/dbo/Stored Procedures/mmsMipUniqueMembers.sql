
-- =============================================
-- Object:			dbo.mmsMipUniqueMembers
-- Author:			Greg Burdick
-- Create date: 	10/30/2008,  releasing on 11/26/08 dbcr_3879a
-- Description:		This sp provides misc. counts for the Unique Interest and New Membership
--					Summary sections of the Interest Summary report
-- Modified date:	1/19/2009 GRB; rr361 changes deploying with dbcr_4067 on 1/21/2009
-- 	
-- Exec mmsMipUniqueMembers '151', '12/1/08', '12/31/08 11:59 PM'
-- =============================================

CREATE			PROC [dbo].[mmsMipUniqueMembers] 
(
	@ClubIDList VARCHAR(2000),
	@StartDate SMALLDATETIME,
	@EndDate SMALLDATETIME
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

CREATE TABLE #tmpList (StringField Int)
CREATE TABLE #Clubs (ClubID Int)
IF @ClubIDList <> 'All'
	BEGIN
		EXEC procParseIntegerList @ClubIDList
		INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
		TRUNCATE TABLE #tmpList
	END
ELSE
	BEGIN
		INSERT INTO #Clubs (ClubID) SELECT ClubID FROM dbo.vClub
	END

SELECT 
(SELECT Count(*) [Total Interest Summary Count]
FROM vMIPMemberCategoryItem mmci
JOIN vMIPCategoryItem mci ON mci.MIPCategoryItemID = mmci.MIPCategoryItemID
	JOIN (
			SELECT MemberID
			FROM vMembership ms
				JOIN #Clubs tc ON ms.ClubID = tc.ClubID
				JOIN vMember vm ON ms.MembershipID = vm.MembershipID
			WHERE 
				ValMembershipStatusID <> 1	-- non-terminated memberships only
				AND ActiveFlag = 1
				AND ValMemberTypeID <> 4		-- non-junior members only
				) a ON mmci.MemberID = a.MemberID
WHERE mmci.InsertedDateTime >= @StartDate
	AND mmci.InsertedDateTime <= @EndDate
	AND mci.ActiveFlag = 1		
) [Total Interest Summary Count],					-- same as in dbo.mmsMipCategory

(SELECT COUNT(DISTINCT vm.MemberID) TotalMembers	-- spec. #16
		FROM vMembership ms
			JOIN #Clubs tc ON ms.ClubID = tc.ClubID
			JOIN vMember vm ON ms.MembershipID = vm.MembershipID
		WHERE ValMembershipStatusID <> 1	-- non-terminated memberships only
			AND ActiveFlag = 1
			AND ValMemberTypeID <> 4	-- non-junior members only
		) TotalMembers,

(SELECT COUNT(DISTINCT m.MemberID) NewMembers	-- spec. #18 'New Members'
FROM vMIPCategoryItem mci
	JOIN vMIPMemberCategoryItem mmci ON mmci.MIPCategoryItemID = mci.MIPCategoryItemID
	JOIN vMember m ON m.MemberID = mmci.MemberID
	JOIN (
		SELECT MemberID
		FROM vMembership ms
			JOIN #Clubs tc ON ms.ClubID = tc.ClubID
			JOIN vMember vm ON ms.MembershipID = vm.MembershipID
		WHERE ValMembershipStatusID <> 1	-- non-terminated memberships only
			AND ActiveFlag = 1
			AND ValMemberTypeID <> 4	-- non-junior members only
			) a ON mmci.MemberID = a.MemberID
	LEFT JOIN vEmployee e ON e.MemberID = m.MemberID
WHERE e.EmployeeID IS NULL
	AND mmci.InsertedDateTime >= @StartDate
	AND mmci.InsertedDateTime <= @EndDate
	AND mci.ActiveFlag = 1					-- active interests only
) NewMembers,

(SELECT COUNT(DISTINCT m.MemberID) NewEmployees	-- spec. #20 'New Team Members'
FROM vMIPCategoryItem mci
	JOIN vMIPMemberCategoryItem mmci ON mmci.MIPCategoryItemID = mci.MIPCategoryItemID
	JOIN vMember m ON m.MemberID = mmci.MemberID
	JOIN (
		SELECT MemberID
		FROM vMembership ms
			JOIN #Clubs tc ON ms.ClubID = tc.ClubID
			JOIN vMember vm ON ms.MembershipID = vm.MembershipID
		WHERE ValMembershipStatusID <> 1	-- non-terminated memberships only
			AND ActiveFlag = 1
			AND ValMemberTypeID <> 4	-- non-junior members only
			) a ON mmci.MemberID = a.MemberID
	JOIN vEmployee e ON e.MemberID = m.MemberID
WHERE mmci.InsertedDateTime >= @StartDate
	AND mmci.InsertedDateTime <= @EndDate
	AND mci.ActiveFlag = 1					-- active interests only
) NewEmployees,

(SELECT COUNT(DISTINCT m.MemberID) TotalNew
FROM vMIPCategoryItem mci
	JOIN vMIPMemberCategoryItem mmci ON mmci.MIPCategoryItemID = mci.MIPCategoryItemID
	JOIN vMember m ON m.MemberID = mmci.MemberID
	JOIN (
		SELECT MemberID
		FROM vMembership ms
			JOIN #Clubs tc ON ms.ClubID = tc.ClubID
			JOIN vMember vm ON ms.MembershipID = vm.MembershipID
		WHERE ValMembershipStatusID <> 1	-- non-terminated memberships only
			AND ActiveFlag = 1
			AND ValMemberTypeID <> 4	-- non-junior members only
			) a ON mmci.MemberID = a.MemberID
WHERE mmci.InsertedDateTime >= @StartDate
	AND mmci.InsertedDateTime <= @EndDate
	AND mci.ActiveFlag = 1					-- active interests only
) TotalNew,

(SELECT COUNT(DISTINCT m.MemberID) TotalMembers	-- spec. #19 'Total Members'
FROM vMIPCategoryItem mci
	JOIN vMIPMemberCategoryItem mmci ON mmci.MIPCategoryItemID = mci.MIPCategoryItemID
	JOIN vMember m ON m.MemberID = mmci.MemberID
	JOIN (
		SELECT MemberID
		FROM vMembership ms
			JOIN #Clubs tc ON ms.ClubID = tc.ClubID
			JOIN vMember vm ON ms.MembershipID = vm.MembershipID
		WHERE ValMembershipStatusID <> 1	-- non-terminated memberships only
			AND ActiveFlag = 1
			AND ValMemberTypeID <> 4	-- non-junior members only
			) a ON mmci.MemberID = a.MemberID
	LEFT JOIN vEmployee e ON e.MemberID = m.MemberID
WHERE e.EmployeeID IS NULL
	AND mci.ActiveFlag = 1					-- active interests only
) TotalMembers,

(SELECT COUNT(DISTINCT m.MemberID) TotalEmployees	-- spec. #21 'Total Team Members'
FROM vMIPCategoryItem mci
	JOIN vMIPMemberCategoryItem mmci ON mmci.MIPCategoryItemID = mci.MIPCategoryItemID
	JOIN vMember m ON m.MemberID = mmci.MemberID
	JOIN (
		SELECT MemberID
		FROM vMembership ms
			JOIN #Clubs tc ON ms.ClubID = tc.ClubID
			JOIN vMember vm ON ms.MembershipID = vm.MembershipID
		WHERE ValMembershipStatusID <> 1	-- non-terminated memberships only
			AND ActiveFlag = 1
			AND ValMemberTypeID <> 4	-- non-junior members only
			) a ON mmci.MemberID = a.MemberID
	JOIN vEmployee e ON e.MemberID = m.MemberID
WHERE mci.ActiveFlag = 1	-- active interests only
) TotalEmployees,

--(SELECT COUNT(DISTINCT MemberID) [Newly Joined Member Count]	-- spec. #24 'Newly Joined Member Count'
(SELECT COUNT(DISTINCT ms.MembershipID) [New Memberships]			-- spec. #28 'New Memberships'
FROM vMembership ms   
      JOIN #Clubs tc ON ms.ClubID = tc.ClubID                                                              
      JOIN vMembershipType mt ON ms.MembershipTypeID = mt.MembershipTypeID    
      LEFT JOIN vMembershipTypeAttribute mtr ON mt.MembershipTypeID = mtr.MembershipTypeID
               AND mtr.ValMembershipTypeAttributeID IN (4, 10, 15)
WHERE ValMembershipStatusID <> 1				-- non-terminated memberships only
      AND ms.MembershipTypeID <> 134			-- non-house accounts only
      AND mtr.MembershipTypeAttributeID IS NULL	-- exclude Employee Memberships, Trade out, and VIP
      AND ms.CreatedDateTime >= @StartDate
      AND ms.CreatedDateTime <= @EndDate) [New Memberships],

--(SELECT COUNT(DISTINCT m.MemberID) [Mips Completed At POS] -- spec. #25 'Interest Profile Completed at POS'
(SELECT COUNT(DISTINCT ms.MembershipID) [Mips Completed At POS] -- spec. #29 'Interest Profile Completed at POS'
FROM vMembership ms
	JOIN vMember m ON ms.MembershipID = m.MembershipID
	JOIN #Clubs tc ON ms.ClubID = tc.ClubID
	JOIN vMembershipType mt ON ms.MembershipTypeID = mt.MembershipTypeID	--	1/15/2009 GRB: added;
	LEFT JOIN vMembershipTypeAttribute mtr ON 
		(	mt.MembershipTypeID = mtr.MembershipTypeID
            AND mtr.ValMembershipTypeAttributeID IN (4, 10, 15)
		)
	JOIN vMIPMemberCategoryItem mci ON m.MemberID = mci.MemberID
	LEFT JOIN vMembershipMessage mm ON 
		(	mm.ValMembershipMessageTypeID = 130
			AND OpenEmployeeID = -3
			AND LEFT(RIGHT(mm.Comment,10),9) = m.MemberID
			AND ABS(DATEDIFF(mm,mm.OpenDateTime,mci.InsertedDateTime)) <= 30
		)
WHERE mm.MembershipMessageID IS NULL
	AND ValMembershipStatusID <> 1				-- non-terminated memberships only
	AND ms.MembershipTypeID <> 134				--	1/14/2009 GRB: added; exclude house accounts
	AND mtr.MembershipTypeAttributeID IS NULL	-- exclude Employee Memberships, Trade out, and VIP
	AND ms.CreatedDateTime >= @StartDate		--	1/14/2009 GRB: added; 
	AND	ms.CreatedDateTime <= @EndDate			--	1/14/2009 GRB: added; 

) [Mips Completed At POS]

DROP TABLE #tmpList
DROP TABLE #Clubs

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END
