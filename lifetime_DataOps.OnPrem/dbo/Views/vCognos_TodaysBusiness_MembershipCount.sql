
CREATE VIEW [dbo].[vCognos_TodaysBusiness_MembershipCount]
AS
-- ===============================================================================================================================
-- Object:			dbo.vCognos_TodaysBusiness_MembershipCount
-- Author:			
-- Create date: 	
-- Description:		
-- Modified date:	11/11/2009 GRB: per QC# 3976, replaced use of TermReasonDescription values with use of 
--					TerminationReasonID values; deploying 11/18/2009 via dbcr_5280;
--                  04/23/2010 MLL: Replaced "30Day" with "MoneyBack"
--                  05/06/2010 MLL: Added "DSSR_Diamond" to Description filter
--                  04/21/2011 QC #7068: Added "DSSR_BronzeElite", "DSSR_GoldElite", "DSSR_PlatinumElite" to Description filter
-- ===================================================================================================================================
--Query #1 - Today’s new memberships 
SELECT 
	ISNULL(VSA.Description, 'None Designated') SalesAreaName,
	C.ClubName ClubName,
	CAST(CASE WHEN DATEPART(HOUR, GETDATE()) < 7 THEN 'Report through Midnight ' + 
				   DATENAME(Month,DATEADD(DD, -1, GETDATE())) + ' ' + CAST(DAY(DATEADD(DD, -1, GETDATE())) AS VARCHAR(2)) + ', ' + CAST(Year(DATEADD(DD, -1, GETDATE())) AS VARCHAR(4))
			  ELSE DATENAME(Month,GETDATE()) + ' ' + CAST(DAY(GETDATE()) AS VARCHAR(2)) + ', ' + CAST(Year(GETDATE()) AS VARCHAR(4))
	END AS VARCHAR(50)) ReportHeadingText,
	CAST('Today''s Business - ' + CASE WHEN DATEPART(HOUR, GETDATE()) < 7 THEN 
				   DATENAME(Month,DATEADD(DD, -1, GETDATE())) + ' ' + CAST(DAY(DATEADD(DD, -1, GETDATE())) AS VARCHAR(2)) + ', ' + CAST(Year(DATEADD(DD, -1, GETDATE())) AS VARCHAR(4))
			  ELSE DATENAME(Month,GETDATE()) + ' ' + CAST(DAY(GETDATE()) AS VARCHAR(2)) + ', ' + CAST(Year(GETDATE()) AS VARCHAR(4))
	END AS VARCHAR(50)) TodaysBusiness_DateHeader,
	COUNT(DISTINCT MS.MembershipID) TodaysBusiness_NewMembershipCount,
	0     TodaysBusiness_MoneyBackCancelCount,
	CAST('DSSR MTD - ' + CASE WHEN (((DATEPART(HOUR, GETDATE()) >= 7) AND DATEPART(DD,GETDATE()) = 1) OR 
							   ((DATEPART(HOUR, GETDATE())  < 7) AND DATEPART(DD,GETDATE()) = 2))
						 THEN ''
						 WHEN DATEPART(HOUR, GETDATE()) >= 7
						 THEN DATENAME(Month,DATEADD(DD, -1, GETDATE())) + ' ' + CAST(DAY(DATEADD(DD, -1, GETDATE())) AS VARCHAR(2)) + ', ' + CAST(Year(DATEADD(DD, -1, GETDATE())) AS VARCHAR(4))
						 ELSE DATENAME(Month,DATEADD(DD, -2, GETDATE())) + ' ' + CAST(DAY(DATEADD(DD, -2, GETDATE())) AS VARCHAR(2)) + ', ' + CAST(Year(DATEADD(DD, -2, GETDATE())) AS VARCHAR(4))
						 END AS VARCHAR(50)) DSSRMTD_DateHeader,
	0     DSSRMTD_NewMembershipCount,
	0     DSSRMTD_MoneyBackCancelCount
FROM vClub C
JOIN vMembership MS
  ON MS.ClubID = C.ClubID
JOIN vMembershipType MT
  ON MT.MembershipTypeID = MS.MembershipTypeID
JOIN vMembershipTypeAttribute MTA
  ON MTA.MembershipTypeID = MT.MembershipTypeID
JOIN vValMembershipTypeAttribute VMTA
  ON VMTA.ValMembershipTypeAttributeID = MTA.ValMembershipTypeAttributeID
JOIN vValSalesArea VSA
  ON VSA.ValSalesAreaID = C.ValSalesAreaID
WHERE VMTA.Description IN ('DSSR_Express', 'DSSR_Bronze', 'DSSR_Gold', 'DSSR_Platinum','DSSR_BronzeElite', 'DSSR_GoldElite', 'DSSR_PlatinumElite', 'DSSR_Onyx', 'DSSR_Ovation', 'DSSR_Diamond')
  AND ((CAST(MS.CreatedDateTime AS VARCHAR(11)) = CAST(GETDATE() AS VARCHAR(11)) AND DATEPART(HOUR, GETDATE()) >= 7) --After 7am Today
       OR
       (CAST(MS.CreatedDateTime AS VARCHAR(11)) = CAST(DATEADD(DD, -1, GETDATE()) AS VARCHAR(11)) AND DATEPART(HOUR, GETDATE()) < 7)) --Before 7am Today
GROUP BY VSA.Description, C.ClubName

UNION ALL

--Query #2 - Today’s 30 Day Cancellations 
SELECT 
	ISNULL(VSA.Description, 'None Designated') SalesAreaName,
	C.ClubName ClubName,
	CAST(CASE WHEN DATEPART(HOUR, GETDATE()) < 7 THEN 'Report through Midnight ' + 
				   DATENAME(Month,DATEADD(DD, -1, GETDATE())) + ' ' + CAST(DAY(DATEADD(DD, -1, GETDATE())) AS VARCHAR(2)) + ', ' + CAST(Year(DATEADD(DD, -1, GETDATE())) AS VARCHAR(4))
			  ELSE DATENAME(Month,GETDATE()) + ' ' + CAST(DAY(GETDATE()) AS VARCHAR(2)) + ', ' + CAST(Year(GETDATE()) AS VARCHAR(4))
	END AS VARCHAR(50)) ReportHeadingText,
	CAST('Today''s Business - ' + CASE WHEN DATEPART(HOUR, GETDATE()) < 7 THEN 
				   DATENAME(Month,DATEADD(DD, -1, GETDATE())) + ' ' + CAST(DAY(DATEADD(DD, -1, GETDATE())) AS VARCHAR(2)) + ', ' + CAST(Year(DATEADD(DD, -1, GETDATE())) AS VARCHAR(4))
			  ELSE DATENAME(Month,GETDATE()) + ' ' + CAST(DAY(GETDATE()) AS VARCHAR(2)) + ', ' + CAST(Year(GETDATE()) AS VARCHAR(4))
	END AS VARCHAR(50)) TodaysBusiness_DateHeader,
	0     TodaysBusiness_NewMembershipCount,
	COUNT(DISTINCT MS.MembershipID) TodaysBusiness_MoneyBackCancelCount,
	CAST('DSSR MTD - ' + CASE WHEN (((DATEPART(HOUR, GETDATE()) >= 7) AND DATEPART(DD,GETDATE()) = 1) OR 
							   ((DATEPART(HOUR, GETDATE())  < 7) AND DATEPART(DD,GETDATE()) = 2))
						 THEN ''
						 WHEN DATEPART(HOUR, GETDATE()) >= 7
						 THEN DATENAME(Month,DATEADD(DD, -1, GETDATE())) + ' ' + CAST(DAY(DATEADD(DD, -1, GETDATE())) AS VARCHAR(2)) + ', ' + CAST(Year(DATEADD(DD, -1, GETDATE())) AS VARCHAR(4))
						 ELSE DATENAME(Month,DATEADD(DD, -2, GETDATE())) + ' ' + CAST(DAY(DATEADD(DD, -2, GETDATE())) AS VARCHAR(2)) + ', ' + CAST(Year(DATEADD(DD, -2, GETDATE())) AS VARCHAR(4))
						 END AS VARCHAR(50)) DSSRMTD_DateHeader,
	0     DSSRMTD_NewMembershipCount,
	0     DSSRMTD_MoneyBackCancelCount
FROM vClub C
JOIN vMembership MS
  ON MS.ClubID = C.ClubID
JOIN vMembershipType MT
  ON MT.MembershipTypeID = MS.MembershipTypeID
JOIN vMembershipTypeAttribute MTA
  ON MTA.MembershipTypeID = MT.MembershipTypeID
JOIN vValMembershipTypeAttribute VMTA
  ON VMTA.ValMembershipTypeAttributeID = MTA.ValMembershipTypeAttributeID
JOIN vValTerminationReason  VTR
  ON VTR.ValTerminationReasonID = MS.ValTerminationReasonID
JOIN vValSalesArea VSA
  ON VSA.ValSalesAreaID = C.ValSalesAreaID
WHERE VMTA.Description IN ('DSSR_Express', 'DSSR_Bronze', 'DSSR_Gold', 'DSSR_Platinum','DSSR_BronzeElite', 'DSSR_GoldElite', 'DSSR_PlatinumElite', 'DSSR_Onyx', 'DSSR_Ovation', 'DSSR_Diamond')
--  AND VTR.Description IN ('30 Day Cancellation', '30-Day Non-Paid', '30-Day Duplicate')	-- commented out 11/11/2009 GRB
	AND VTR.ValTerminationReasonID IN (21, 41, 42, 59)											-- added 11/11/2009 GRB
  AND ((CAST(MS.ExpirationDate AS VARCHAR(11)) = CAST(GETDATE() AS VARCHAR(11)) AND DATEPART(HOUR, GETDATE()) >= 7) --After 7am Today
       OR
       (CAST(MS.ExpirationDate AS VARCHAR(11)) = CAST(DATEADD(DD, -1, GETDATE()) AS VARCHAR(11)) AND DATEPART(HOUR, GETDATE()) < 7)) --Before 7am Today
GROUP BY VSA.Description, C.ClubName
