

CREATE PROC [dbo].[mmsDepartmentProgram_Revenue] (
	@StartPostDate AS SMALLDATETIME,
	@EndPostDate AS  SMALLDATETIME,
	@ClubIDList AS VARCHAR(2000),
    @ReportingDepartment AS VARCHAR(50)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

----============================================================================
---- Object:		dbo.mmsDepartmentProgram_Revenue
---- Author:		Susan Myrick
---- Create Date:	7/7/08
---- Description:	Returns revenue records for the Fitness and Member Activities 
----				departments for the selected club(s) and date range
---- Modified:      5/31/2011 BSD: Removed Mixed Combat Arts from non-deferred department list
---- Modified:      1/18/2011 BSD: Updated for new ClubID = 9999 business rule to use TranItem.ClubID
---- Modified:		10/20/2010 BSDL Changed an equal join to left join on vValRegion
---- Modified:		10/19/2010 BSD: Updated filter to act the same with ClubID=9999 as ClubID=13
---- Modified:      6/24/2010 MLL: Modified @EndPostDate setting to end of day for reporting purposes
----                               when @ReportingDepartment not "Fitness" nor "Nutrition"
---- Modified:      1/5/2010  SRM: RR 405 - Added Commissioned EmployeeID, Name and CommissionedQuantity
---- Modified:		1/28/2009 GRB: changed view referenced in a condition of WHERE clause
--					1/27/2009 GRB: added Aquatics section per rr373;
--					9/12/08 - added Tennis reporting option
--	EXEC mmsDepartmentProgram_Revenue '1/1/2009', '6/15/2009 11:59 PM', '158', 'Aquatics'
---- ===========================================================================

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

DECLARE @AdjustedEndPostDate AS SMALLDATETIME
DECLARE @StartDate AS DATETIME
DECLARE @EndDate AS DATETIME
DECLARE @DeferredRevenueYearMonth_Start AS VARCHAR(6)
DECLARE @DeferredRevenueYearMonth_END AS VARCHAR(6)

-----  dates used to evaluate which data source to use
SET @StartDate = (Select MIN(PostDateTime)from dbo.vMMSRevenueReportSummary)
SET @EndDate = Convert(DATETIME,Convert(VARCHAR,Getdate(),101),101)
----- adjusting the date passed from the user so all transactions posted for the full last minute are returned
SET @AdjustedEndPostDate = DATEADD(mi,1,@EndPostDate)
----- Setting parameter dates for deferred revenue reporting
SET @DeferredRevenueYearMonth_Start = Substring(CONVERT(VARCHAR,@StartPostDate,112),1,6)
SET @DeferredRevenueYearMonth_End = Substring(CONVERT(VARCHAR,@EndPostDate,112),1,6)

CREATE TABLE #tmpList(StringField VARCHAR(50))
CREATE TABLE #ClubIDs(ClubID INT)
IF @ClubIDList <> '0'
  BEGIN
   EXEC procParseIntegerList @ClubIDList
   INSERT INTO #ClubIDs(ClubID) SELECT StringField FROM #tmpList
   TRUNCATE TABLE #tmpList
  END
ELSE
  BEGIN
   INSERT INTO #ClubIDs Values(0)
  END

IF @ReportingDepartment in ('Endurance','Group Training','LifeLab/Testing-HRM',
'Nutrition Services','Personal Training','Pilates')
BEGIN

------  Use vMMSRevenueReportSummary if date range is within the range of the stored data
IF @StartPostDate >= @StartDate AND 
   @EndPostDate <= @EndDate

BEGIN
	SELECT MMSR.PostingClubName, MMSR.PostingClubID,MMSR.PostingRegionDescription,MMSR.DeptDescription, 
       MMSR.ProductID,MMSR.ProductDescription,MMSR.PostDateTime,
       Case When CSC.CommissionCount Is Null			----- Added RR 405
             Then MMSR.ItemAmount
            When CSC.CommissionCount = 1
             Then MMSR.ItemAmount
            When CSC.CommissionCount > 1
             Then MMSR.ItemAmount / CSC.CommissionCount
            End ItemAmount,
       MMSR.MembershipClubname,MMSR.TranTypeDescription,
       MMSR.MembershipID,MMSR.MemberID,MMSR.MemberFirstname, MMSR.MemberLastname, MMSR.TranItemID,
       MMSR.TranMemberJoinDate,MMSR.TranClubID,Quantity, @StartPostDate AS ReportStartDate, @EndPostDate AS ReportEndDate,
       E.EmployeeID AS CommissionedEmployeeID, E.FirstName As CommissionedEmployeeFirstName,  ----- Added RR 405
       E.LastName as CommissionedEmployeeLastName,		----- Added RR 405
       Case When CSC.CommissionCount Is Null			----- Added RR 405
             Then MMSR.Quantity
            When CSC.CommissionCount = 1
             Then MMSR.Quantity
            When CSC.CommissionCount > 1
                 Then MMSR.Quantity *.5
            End CommissionQuantity,
       VPG.Description AS ProductGroupDescription
    FROM vMMSRevenueReportSummary MMSR
     JOIN #ClubIDs CS
       ON (MMSR.PostingClubID = CS.ClubID or CS.ClubID = 0)
     Left Join vSaleCommission SC							----- Added RR 405
       ON MMSR.TranItemID = SC.TranItemID
     Left Join vCommissionSplitCalc CSC						----- Added RR 405
       On SC.TranItemID = CSC.TranItemID
     Left Join vEmployee E									----- Added RR 405
       On SC.EmployeeID = E.EmployeeID
               LEFT JOIN dbo.vProductGroup PG
                 ON PG.ProductID = MMSR.ProductID
               LEFT JOIN dbo.vValProductGroup VPG
                 ON VPG.ValProductGroupID = PG.ValProductGroupID
    WHERE MMSR.PostDateTime >=@StartPostDate
      AND MMSR.PostDateTime <=@AdjustedEndPostDate
      AND MMSR.ItemAmount <> 0
      AND VPG.RevenueReportingDepartment = @ReportingDepartment
    
END
Else 
BEGIN
    SELECT CASE WHEN C.ClubID = 9999 THEN CASE WHEN TI.ClubID is NULL THEN C.ClubName ELSE TranItemClub.ClubName END -- 1/18/2011 BSD
                WHEN MMST.ReasonCodeID = 108  THEN C2.ClubName
                WHEN C3.ClubName IS NULL THEN C.ClubName 
                ELSE C3.ClubName END AS PostingClubName,
           CASE WHEN C.ClubID = 9999 THEN CASE WHEN TI.ClubID is NULL THEN C.ClubID ELSE TranItemClub.ClubID END -- 1/18/2011 BSD
                WHEN MMST.ReasonCodeID = 108  THEN C2.ClubID
                WHEN C3.ClubName IS NULL THEN C.ClubID 
                ELSE C3.ClubID END AS PostingClubid,
           CASE WHEN C.ClubID = 9999 THEN CASE WHEN TI.ClubID is NULL THEN CVR.Description ELSE TranItemRegion.Description END -- 1/18/2011 BSD
                WHEN MMST.ReasonCodeID = 108  THEN C2VR.Description
                WHEN C3.ClubName IS NULL THEN  CVR.Description
                ELSE C3VR.Description END AS PostingRegionDescription,
           D.Description AS DeptDescription,P.ProductID, P.Description AS ProductDescription,MMST.PostDateTime,
           Case When CSC.CommissionCount Is Null			----- Added RR 405
             Then TI.ItemAmount
            When CSC.CommissionCount = 1
             Then TI.ItemAmount
            When CSC.CommissionCount > 1
             Then TI.ItemAmount / CSC.CommissionCount
            End ItemAmount,
           C2.ClubName AS MembershipClubname,VTT.Description AS TranTypeDescription,
           MMST.MembershipID,MMST.MemberID,M.FirstName AS MemberFirstname, M.LastName AS MemberLastname,
           TI.TranItemID,M.JoinDate AS TranMemberJoinDate,MMST.ClubID AS TranClubid,TI.Quantity,
           @StartPostDate AS ReportStartDate, @EndPostDate AS ReportEndDate,
           E.EmployeeID AS CommissionedEmployeeID, E.FirstName As CommissionedEmployeeFirstName,  ----- Added RR 405
           E.LastName as CommissionedEmployeeLastName,		----- Added RR 405
           Case When CSC.CommissionCount Is Null			----- Added RR 405
                 Then TI.Quantity
                When CSC.CommissionCount = 1
                 Then TI.Quantity
                When CSC.CommissionCount > 1
                 Then TI.Quantity * .5
                End CommissionQuantity,
           VPG.Description AS ProductGroupDescription

          FROM dbo.vMMSTran MMST 
               JOIN vClub C
                 ON C.ClubID = MMST.ClubID
               JOIN #ClubIDs CI							
                 ON (C.ClubID = CI.ClubID or CI.ClubID = 0)			
               JOIN vValRegion CVR
                 ON C.ValRegionID = CVR.ValRegionID
               JOIN vTranItem TI
                 ON TI.MMSTranID = MMST.MMSTranID
               LEFT JOIN vClub TranItemClub -- 1/18/2011 BSD
                 ON TI.ClubID = TranItemClub.ClubID -- 1/18/2011 BSD
               LEFT JOIN vValRegion TranItemRegion -- 1/18/2011 BSD
                 ON TranItemClub.ValRegionID = TranItemRegion.ValRegionID -- 1/18/2011 BSD
               JOIN vProduct P
                 ON P.ProductID = TI.ProductID
               JOIN vDepartment D
                 ON D.DepartmentID = P.DepartmentID
               JOIN vMembership MS
                 ON MS.MembershipID = MMST.MembershipID
               JOIN vClub C2
                 ON MS.ClubID = C2.ClubID
               JOIN vValRegion C2VR
                 ON C2.ValRegionID = C2VR.ValRegionID
               JOIN vValTranType VTT
                 ON MMST.ValTranTypeID = VTT.ValTranTypeID
               JOIN vMember M
                 ON M.MemberID = MMST.MemberID
       	   LEFT JOIN dbo.vMMSTranRefund MTR 
             ON MMST.MMSTranID = MTR.MMSTranID AND MMST.ReasonCodeID <> 108
           LEFT JOIN dbo.vMMSTranRefundMMSTran MTRMT
             ON MTRMT.MMSTranRefundID = MTR.MMSTranRefundID
           LEFT JOIN dbo.vMMSTran MMST1 
             ON  MTRMT.OriginalMMSTranID = MMST1.MMSTranID
           LEFT JOIN dbo.vClub C3
             ON C3.ClubID = MMST1.ClubID
           LEFT JOIN vValRegion C3VR
             ON C3.ValRegionID = C3VR.ValRegionID
           LEFT JOIN vSaleCommission SC							----- Added RR 405
             ON TI.TranItemID = SC.TranItemID
           LEFT JOIN vCommissionSplitCalc CSC						----- Added RR 405
             On SC.TranItemID = CSC.TranItemID
           LEFT JOIN vEmployee E									----- Added RR 405
             On SC.EmployeeID = E.EmployeeID
               LEFT JOIN dbo.vProductGroup PG
                 ON PG.ProductID = P.ProductID
               LEFT JOIN dbo.vValProductGroup VPG
                 ON VPG.ValProductGroupID = PG.ValProductGroupID
         WHERE	MMST.PostDateTime >= @StartPostDate 
			AND	MMST.PostDateTime < @AdjustedEndPostdate 
			AND	MMST.TranVoidedID IS NULL 
			AND	VTT.ValTranTypeID IN (1, 3, 4, 5) 
			AND	C.ClubID not in (13)--10/19/2010 BSD -- 1/18/2011 BSD
			AND	TI.ItemAmount <> 0
            AND VPG.REvenueReportingDepartment = @ReportingDepartment

  UNION ALL

	  SELECT CASE WHEN MMST.ReasonCodeID = 108 OR C3.ClubName IS NULL 
                  THEN C2.ClubName 
                  ELSE C3.ClubName END AS PostingClubName, 
             CASE WHEN MMST.ReasonCodeID = 108 OR C3.ClubID IS NULL 
                  THEN C2.ClubID 
                  ELSE C3.ClubID END AS PostingClubid,
             CASE WHEN MMST.ReasonCodeID = 108 OR C3.ClubID IS NULL 
                  THEN C2VR.Description 
                  ELSE C3VR.Description END AS PostingRegionDescription,
             D.Description AS DeptDescription,P.ProductID,P.Description AS ProductDescription,MMST.PostDateTime,
             Case When CSC.CommissionCount Is Null			----- Added RR 405
                   Then TI.ItemAmount
                  When CSC.CommissionCount = 1
                   Then TI.ItemAmount
                  When CSC.CommissionCount > 1
                   Then TI.ItemAmount / CSC.CommissionCount
                  End ItemAmount,
             C2.ClubName AS MembershipClubname,VTT.Description AS TranTypeDescription,  
             MMST.MembershipID,M.MemberID,M.FirstName AS MemberFirstname, M.LastName AS MemberLastname,
	         TI.TranItemID,M.JoinDate AS TranMemberJoinDate,MMST.ClubID AS TranClubid, TI.Quantity,
		     @StartPostDate AS ReportStartDate, @EndPostDate AS ReportEndDate,
             E.EmployeeID AS CommissionedEmployeeID, E.FirstName As CommissionedEmployeeFirstName,  ----- Added RR 405
             E.LastName as CommissionedEmployeeLastName,		----- Added RR 405
             Case When CSC.CommissionCount Is Null			----- Added RR 405
                    Then TI.Quantity
                  When CSC.CommissionCount = 1
                    Then TI.Quantity
                  When CSC.CommissionCount > 1
                    Then TI.Quantity * .5
                  End CommissionQuantity,
             VPG.Description AS ProductGroupDescription

	  FROM dbo.vMMSTran MMST
	       JOIN vClub C
	         ON C.ClubID = MMST.ClubID
	       JOIN vTranItem TI
	         ON TI.MMSTranID = MMST.MMSTranID
	       JOIN vProduct P
	         ON P.ProductID = TI.ProductID
	       JOIN vDepartment D
             ON D.DepartmentID = P.DepartmentID
	       JOIN vMembership MS
	         ON MS.MembershipID = MMST.MembershipID
	       JOIN vClub C2
	         ON MS.ClubID = C2.ClubID
           --JOIN #ClubIDs CI
             --ON (CI.ClubID = C2.ClubID or CI.ClubID = 0)
	       JOIN vValRegion C2VR
	         ON C2.ValRegionID = C2VR.ValRegionID
	       JOIN vValTranType VTT
	         ON MMST.ValTranTypeID = VTT.ValTranTypeID
	       JOIN vMember M
	         ON M.MemberID = MMST.MemberID
       	   LEFT JOIN dbo.vMMSTranRefund MTR  
             ON MMST.MMSTranID = MTR.MMSTranID  AND MMST.ReasonCodeID <> 108
           LEFT JOIN dbo.vMMSTranRefundMMSTran MTRMT
             ON MTRMT.MMSTranRefundID = MTR.MMSTranRefundID
           LEFT JOIN dbo.vMMSTran MMST1 
             ON  MTRMT.OriginalMMSTranID = MMST1.MMSTranID
           LEFT JOIN dbo.vClub C3
             ON C3.ClubID = MMST1.ClubID
           LEFT JOIN vValRegion C3VR                         ----BSD: RR 424
	         ON C3.ValRegionID = C3VR.ValRegionID
           LEFT JOIN vSaleCommission SC							----- Added RR 405
             ON TI.TranItemID = SC.TranItemID
           LEFT JOIN vCommissionSplitCalc CSC						----- Added RR 405
             On SC.TranItemID = CSC.TranItemID
           LEFT JOIN vEmployee E									----- Added RR 405
             On SC.EmployeeID = E.EmployeeID
               LEFT JOIN dbo.vProductGroup PG
                 ON PG.ProductID = MMSR.ProductID
               LEFT JOIN dbo.vValProductGroup VPG
                 ON VPG.ValProductGroupID = PG.ValProductGroupID
	  WHERE --ISNULL(C3.ClubID,C2.ClubID) IN (SELECT ClubID FROM #ClubIDs) AND 
            CASE WHEN MMST.ReasonCodeID = 108 OR C3.ClubID IS NULL 
                 THEN C2.ClubID 
                  ELSE C3.ClubID END  IN (SELECT ClubID FROM #ClubIDs) AND 
            C.ClubID in (13) AND--10/19/2010 BSD -- 1/18/2011 BSD
	        MMST.PostDateTime >= @StartPostDate AND
	        MMST.PostDateTime < @AdjustedEndPostDate AND
	        VTT.ValTranTypeID IN (1, 3, 4, 5) AND
	        MMST.TranVoidedID IS NULL AND
			TI.ItemAmount <> 0 AND	
            VPG.RevenueReportingDepartment = @ReportingDepartment
         

  END

DROP TABLE #ClubIDs				
DROP TABLE #tmpList

END


IF @ReportingDepartment = 'Nutritionals'
BEGIN

------  Use vMMSRevenueReportSummary if date range is within the range of the stored data
IF @StartPostDate >= @StartDate AND 
   @EndPostDate <= @EndDate

BEGIN
	SELECT MMSR.PostingClubName, MMSR.PostingClubID,MMSR.PostingRegionDescription,MMSR.DeptDescription, MMSR.ProductID,
           MMSR.ProductDescription,PostDateTime,
           Case When CSC.CommissionCount Is Null			----- Added RR 405
             Then MMSR.ItemAmount
            When CSC.CommissionCount = 1
             Then MMSR.ItemAmount
            When CSC.CommissionCount > 1
             Then MMSR.ItemAmount / CSC.CommissionCount
            End ItemAmount,
           MMSR.MembershipClubname,MMSR.TranTypeDescription,
           MMSR.MembershipID,MMSR.MemberID,MMSR.MemberFirstname, MMSR.MemberLastname, MMSR.TranItemID,MMSR.TranMemberJoinDate,
           MMSR.TranClubID,MMSR.Quantity, @StartPostDate AS ReportStartDate, @EndPostDate AS ReportEndDate,
           E.EmployeeID AS CommissionedEmployeeID, E.FirstName As CommissionedEmployeeFirstName,  ----- Added RR 405
           E.LastName as CommissionedEmployeeLastName,		----- Added RR 405
           Case When CSC.CommissionCount Is Null			----- Added RR 405
             Then MMSR.Quantity
            When CSC.CommissionCount = 1
             Then MMSR.Quantity
            When CSC.CommissionCount > 1
             Then MMSR.Quantity * .5
            End CommissionQuantity,
           VPG.Description AS ProductGroupDescription

    FROM vMMSRevenueReportSummary MMSR
     JOIN #ClubIDs CS
       ON (MMSR.PostingClubID = CS.ClubID or CS.ClubID = 0)
     Left Join vSaleCommission SC							----- Added RR 405
       ON MMSR.TranItemID = SC.TranItemID
     Left Join vCommissionSplitCalc CSC						----- Added RR 405
       On SC.TranItemID = CSC.TranItemID
     Left Join vEmployee E									----- Added RR 405
       On SC.EmployeeID = E.EmployeeID
               LEFT JOIN dbo.vProductGroup PG
                 ON PG.ProductID = MMSR.ProductID
               LEFT JOIN dbo.vValProductGroup VPG
                 ON VPG.ValProductGroupID = PG.ValProductGroupID
    WHERE MMSR.PostDateTime >=@StartPostDate
      AND MMSR.PostDateTime <=@AdjustedEndPostDate
      AND MMSR.ItemAmount <> 0
      AND VPG.RevenueReportingDepartment = @ReportingDepartment
      
END
Else
BEGIN
    SELECT CASE WHEN C.ClubID = 9999 THEN CASE WHEN TI.ClubID is NULL THEN C.ClubName ELSE TranItemClub.ClubName END -- 1/18/2011 BSD
                WHEN MMST.ReasonCodeID = 108  THEN C2.ClubName
                WHEN C3.ClubName IS NULL THEN C.ClubName 
                ELSE C3.ClubName END AS PostingClubName,
           CASE WHEN C.ClubID = 9999 THEN CASE WHEN TI.ClubID is NULL THEN C.ClubID ELSE TranItemClub.ClubID END -- 1/18/2011 BSD
                WHEN MMST.ReasonCodeID = 108  THEN C2.ClubID
                WHEN C3.ClubName IS NULL THEN C.ClubID 
                ELSE C3.ClubID END AS PostingClubid,
           CASE WHEN C.ClubID = 9999 THEN CASE WHEN TI.ClubID is NULL THEN CVR.Description ELSE TranItemRegion.Description END -- 1/18/2011 BSD
                WHEN MMST.ReasonCodeID = 108  THEN C2VR.Description
                WHEN C3.ClubName IS NULL THEN CVR.Description 
                ELSE C3VR.Description END AS PostingRegionDescription,
           D.Description AS DeptDescription,P.ProductID, P.Description AS ProductDescription,MMST.PostDateTime,
           Case When CSC.CommissionCount Is Null			----- Added RR 405
             Then TI.ItemAmount
            When CSC.CommissionCount = 1
             Then TI.ItemAmount
            When CSC.CommissionCount > 1
             Then TI.ItemAmount / CSC.CommissionCount
            End ItemAmount,
           C2.ClubName AS MembershipClubname,VTT.Description AS TranTypeDescription,
           MMST.MembershipID,MMST.MemberID,M.FirstName AS MemberFirstname, M.LastName AS MemberLastname,
           TI.TranItemID,M.JoinDate AS TranMemberJoinDate,MMST.ClubID AS TranClubid,TI.Quantity,
           @StartPostDate AS ReportStartDate, @EndPostDate AS ReportEndDate,
           E.EmployeeID AS CommissionedEmployeeID, E.FirstName As CommissionedEmployeeFirstName,  ----- Added RR 405
           E.LastName as CommissionedEmployeeLastName,		----- Added RR 405
           Case When CSC.CommissionCount Is Null			----- Added RR 405
                 Then TI.Quantity
                When CSC.CommissionCount = 1
                 Then TI.Quantity
                When CSC.CommissionCount > 1
                 Then TI.Quantity * .5
                End CommissionQuantity,
           VPG.Description AS ProductGroupDescription

          FROM dbo.vMMSTran MMST 
               JOIN vClub C
                 ON C.ClubID = MMST.ClubID
               JOIN #ClubIDs CI							
                 ON (C.ClubID = CI.ClubID or CI.ClubID = 0)			
               JOIN vValRegion CVR
                 ON C.ValRegionID = CVR.ValRegionID
               JOIN vTranItem TI
                 ON TI.MMSTranID = MMST.MMSTranID
               LEFT JOIN vClub TranItemClub --1/18/2011 BSD
                 ON TI.ClubID = TranItemClub.ClubID --1/18/2011 BSD
               LEFT JOIN vValRegion TranItemRegion --1/18/2011 BSD
                 ON TranItemClub.ValRegionID = TranItemRegion.ValRegionID --1/18/2011 BSD
               JOIN vProduct P
                 ON P.ProductID = TI.ProductID
               JOIN vDepartment D
                 ON D.DepartmentID = P.DepartmentID
               JOIN vMembership MS
                 ON MS.MembershipID = MMST.MembershipID
               JOIN vClub C2
                 ON MS.ClubID = C2.ClubID
			   JOIN vValRegion C2VR
				 ON C2.ValRegionID = C2VR.ValRegionID
               JOIN vValTranType VTT
                 ON MMST.ValTranTypeID = VTT.ValTranTypeID
               JOIN vMember M
                 ON M.MemberID = MMST.MemberID
       	       LEFT JOIN dbo.vMMSTranRefund MTR 
                 ON MMST.MMSTranID = MTR.MMSTranID AND MMST.ReasonCodeID <> 108
               LEFT JOIN dbo.vMMSTranRefundMMSTran MTRMT
                 ON MTRMT.MMSTranRefundID = MTR.MMSTranRefundID
               LEFT JOIN dbo.vMMSTran MMST1 
                 ON  MTRMT.OriginalMMSTranID = MMST1.MMSTranID
               LEFT JOIN dbo.vClub C3
                 ON C3.ClubID = MMST1.ClubID
               LEFT JOIN vValRegion C3VR
                 ON C3.ValRegionID = C3VR.ValRegionID
               LEFT JOIN vSaleCommission SC							----- Added RR 405
                 ON TI.TranItemID = SC.TranItemID
               LEFT JOIN vCommissionSplitCalc CSC						----- Added RR 405
                 On SC.TranItemID = CSC.TranItemID
               LEFT JOIN vEmployee E									----- Added RR 405
                 On SC.EmployeeID = E.EmployeeID
               LEFT JOIN dbo.vProductGroup PG
                 ON PG.ProductID = P.ProductID
               LEFT JOIN dbo.vValProductGroup VPG
                 ON VPG.ValProductGroupID = PG.ValProductGroupID
         WHERE	MMST.PostDateTime >= @StartPostDate 
			AND	MMST.PostDateTime < @AdjustedEndPostdate 
			AND	MMST.TranVoidedID IS NULL 
			AND	VTT.ValTranTypeID IN (1, 3, 4, 5) 
			AND	C.ClubID not in(13)  --10/19/2010 BSD -- 1/18/2011 BSD
			AND	TI.ItemAmount <> 0		
            AND VPG.RevenueReportingDepartment = @ReportingDepartment
			


  UNION ALL

	  SELECT CASE WHEN MMST.ReasonCodeID = 108 OR C3.ClubName IS NULL 
                  THEN C2.ClubName 
                  ELSE C3.ClubName END AS PostingClubName, 
             CASE WHEN MMST.ReasonCodeID = 108 OR C3.ClubID IS NULL 
                  THEN C2.ClubID 
                  ELSE C3.ClubID END AS PostingClubid,
             CASE WHEN MMST.ReasonCodeID = 108 OR C3.ClubID IS NULL 
                  THEN C2VR.Description 
                  ELSE C3VR.Description END AS PostingRegionDescription,
             D.Description AS DeptDescription,P.ProductID,P.Description AS ProductDescription,MMST.PostDateTime,
             Case When CSC.CommissionCount Is Null			----- Added RR 405
                  Then TI.ItemAmount
                  When CSC.CommissionCount = 1
                  Then TI.ItemAmount
                  When CSC.CommissionCount > 1
                  Then TI.ItemAmount / CSC.CommissionCount
                  End ItemAmount,
             C2.ClubName AS MembershipClubname,VTT.Description AS TranTypeDescription,  
             MMST.MembershipID,M.MemberID,M.FirstName AS MemberFirstname, M.LastName AS MemberLastname,
	         TI.TranItemID,M.JoinDate AS TranMemberJoinDate,MMST.ClubID AS TranClubid, TI.Quantity,
		     @StartPostDate AS ReportStartDate, @EndPostDate AS ReportEndDate,
             E.EmployeeID AS CommissionedEmployeeID, E.FirstName As CommissionedEmployeeFirstName,  ----- Added RR 405
             E.LastName as CommissionedEmployeeLastName,		----- Added RR 405
             Case When CSC.CommissionCount Is Null			----- Added RR 405
                  Then TI.Quantity
                  When CSC.CommissionCount = 1
                  Then TI.Quantity
                  When CSC.CommissionCount > 1
                  Then TI.Quantity * .5
                  End CommissionQuantity,
             VPG.Description AS ProductGroupDescription

	  FROM dbo.vMMSTran MMST
	       JOIN vClub C
	         ON C.ClubID = MMST.ClubID
	       JOIN vTranItem TI
	         ON TI.MMSTranID = MMST.MMSTranID
	       JOIN vProduct P
	         ON P.ProductID = TI.ProductID
	       JOIN vDepartment D
             ON D.DepartmentID = P.DepartmentID
	       JOIN vMembership MS
	         ON MS.MembershipID = MMST.MembershipID
	       JOIN vClub C2
	         ON MS.ClubID = C2.ClubID
          -- JOIN #ClubIDs CI
           --  ON (CI.ClubID = C2.ClubID or CI.ClubID = 0)
	       JOIN vValRegion C2VR
	         ON C2.ValRegionID = C2VR.ValRegionID
	       JOIN vValTranType VTT
	         ON MMST.ValTranTypeID = VTT.ValTranTypeID
	       JOIN vMember M
	         ON M.MemberID = MMST.MemberID
	       LEFT JOIN dbo.vMMSTranRefund MTR 
             ON MMST.MMSTranID = MTR.MMSTranID AND MMST.ReasonCodeID <> 108
           LEFT JOIN dbo.vMMSTranRefundMMSTran MTRMT
             ON MTRMT.MMSTranRefundID = MTR.MMSTranRefundID
           LEFT JOIN dbo.vMMSTran MMST1 
            ON  MTRMT.OriginalMMSTranID = MMST1.MMSTranID
           LEFT JOIN dbo.vClub C3
            ON C3.ClubID = MMST1.ClubID
           LEFT JOIN vValRegion C3VR                        ----BSD: RR 424
	         ON C3.ValRegionID = C3VR.ValRegionID
           LEFT JOIN vSaleCommission SC							----- Added RR 405
             ON TI.TranItemID = SC.TranItemID
           LEFT JOIN vCommissionSplitCalc CSC						----- Added RR 405
             On SC.TranItemID = CSC.TranItemID
           LEFT JOIN vEmployee E									----- Added RR 405
             On SC.EmployeeID = E.EmployeeID
               LEFT JOIN dbo.vProductGroup PG
                 ON PG.ProductID = P.ProductID
               LEFT JOIN dbo.vValProductGroup VPG
                 ON VPG.ValProductGroupID = PG.ValProductGroupID
	  WHERE --ISNULL(C3.ClubID,C2.ClubID) IN (SELECT ClubID FROM #ClubIDs) AND 
            CASE WHEN MMST.ReasonCodeID = 108 OR C3.ClubID IS NULL 
                 THEN C2.ClubID 
                  ELSE C3.ClubID END IN (SELECT ClubID FROM #ClubIDs) AND 
            C.ClubID in(13) AND              --10/19/2010 BSD -- 1/18/2011 BSD
	        MMST.PostDateTime >= @StartPostDate AND
	        MMST.PostDateTime < @AdjustedEndPostDate AND
	        VTT.ValTranTypeID IN (1, 3, 4, 5) AND
	        MMST.TranVoidedID IS NULL AND
			TI.ItemAmount <> 0 AND	
            VPG.RevenueReportingDepartment = @ReportingDepartment

  END


DROP TABLE #ClubIDs				
DROP TABLE #tmpList

END

ELSE IF @ReportingDepartment not in ('Endurance','Group Training','LifeLab/Testing-HRM',
'Nutrition Services','Nutritionals','Personal Training','Pilates')

BEGIN

SET @EndPostDate = DATEADD(MI,-1,DATEADD(DD,1,Convert(DATETIME,Convert(VARCHAR,@EndPostDate,101),101)))

	SELECT C.ClubName AS PostingClubName,C.ClubID AS PostingClubID,VMAR.Description AS PostingRegionDescription,
           @ReportingDepartment AS DeptDescription, DRAS.ProductID,P.Description as ProductDescription,
           CONVERT(SMALLDATETIME,(Substring(GLRevenueMonth,5,2)+'/01/'+Substring(GLRevenueMonth,1,4))) AS PostDateTime,
           DRAS.RevenueMonthAllocation AS ItemAmount,NULL AS MembershipClubname,DRAS.TransactionType AS TranTypeDescription,
           NULL AS MembershipID,NULL AS MemberID,NULL AS MemberFirstname, NULL AS MemberLastname, NULL AS TranItemID,
           NULL AS TranMemberJoinDate, NULL AS TranClubID,NULL AS Quantity, @StartPostDate AS ReportStartDate, 
           @EndPostDate AS ReportEndDate, 
           NULL AS EmployeeID, NULL AS CommissionedEmployeeFirstName,  ----- Added RR 405
           NULL AS CommissionedEmployeeLastName,		----- Added RR 405
           NULL AS CommissionQuantity,  				----- Added RR 405
           VPG.Description AS ProductGroupDescription

FROM vDeferredRevenueAllocationSummary DRAS
     JOIN vCLUB C
     ON DRAS.MMSClubID=C.ClubID
     JOIN #ClubIDs CI
     ON (C.ClubID = CI.ClubID or CI.ClubID = 0)
     JOIN vProduct P 
     ON DRAS.ProductID=P.ProductID
     LEFT JOIN vValMemberActivityRegion VMAR
     ON VMAR.ValMemberActivityRegionID = C.ValMemberActivityRegionID
               LEFT JOIN dbo.vProductGroup PG
                 ON PG.ProductID = P.ProductID
               LEFT JOIN dbo.vValProductGroup VPG
                 ON VPG.ValProductGroupID = PG.ValProductGroupID
WHERE DRAS.GLRevenueMonth >= @DeferredRevenueYearMonth_Start
  AND DRAS.GLRevenueMonth <= @DeferredRevenueYearMonth_END
  AND VPG.RevenueReportingDepartment = @ReportingDepartment
  

DROP TABLE #ClubIDs				
DROP TABLE #tmpList

END


 -- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END
