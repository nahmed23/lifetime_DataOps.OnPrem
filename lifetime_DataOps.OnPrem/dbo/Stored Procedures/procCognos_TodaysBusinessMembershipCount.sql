


CREATE PROC [dbo].[procCognos_TodaysBusinessMembershipCount] 

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

SELECT Membership.MembershipID,
       Membership.ClubID,
       Membership.MembershipTypeID,
       CreatedDateTime,
       Membership.ValTerminationReasonID,
       Membership.ExpirationDate,
	   ValMembershipTypeAttribute.Description as Default_MembershipSalesReportingCategory,
	   ValSalesReportingCategory.Description as SalesPromotion_MembershipSalesReportingCategory,
	   CASE WHEN IsNull(ValSalesReportingCategory.Description,'No Sales Promotion') = 'No Sales Promotion'
	        THEN ValMembershipTypeAttribute.Description
			ELSE ValSalesReportingCategory.Description
			END MembershipSalesReportingCategory
INTO #Membership
FROM vMembership Membership WITH (NOLOCK)
  JOIN vMembershipTypeAttribute MembershipTypeAttribute
    ON Membership.MembershipTypeID = MembershipTypeAttribute.MembershipTypeID
  JOIN vValMembershipTypeAttribute  ValMembershipTypeAttribute
    ON MembershipTypeAttribute.ValMembershipTypeAttributeID = ValMembershipTypeAttribute.ValMembershipTypeAttributeID
	AND ValMembershipTypeAttribute.Description IN ('DSSR_Express', 'DSSR_Bronze', 'DSSR_Gold', 'DSSR_Platinum','DSSR_BronzeElite', 'DSSR_GoldElite', 'DSSR_PlatinumElite', 'DSSR_Onyx', 'DSSR_Ovation', 'DSSR_Diamond','DSSR_Other','DSSR_AccessByPricePaid')
  LEFT JOIN vMembershipAttribute  MembershipAttribute
    ON Membership.MembershipID = MembershipAttribute.MembershipID
	AND MembershipAttribute.ValMembershipAttributeTypeID = 3   ---- PromotionID
  LEFT JOIN vSalesPromotion  SalesPromotion
    ON MembershipAttribute.AttributeValue = SalesPromotion.SalesPromotionID
  LEFT JOIN vValSalesReportingCategory  ValSalesReportingCategory 
    ON SalesPromotion.ValSalesReportingCategoryID = ValSalesReportingCategory.ValSalesReportingCategoryID


CREATE INDEX IX_MembershipID ON #Membership(MembershipID)
CREATE INDEX IX_ClubID ON #Membership(ClubID)


--Query #1 - Today’s new memberships 
SELECT ISNULL(VSA.Description, 'None Designated') SalesAreaName,
       C.ClubName ClubName,
       CASE WHEN DATEPART(HOUR, GETDATE()) < 7 
                 THEN 'Report through Midnight ' + Replace(Substring(convert(varchar,getdate()-1,100),1,6)+', '+Substring(convert(varchar,getdate()-1,100),8,4),'  ',' ')
            ELSE Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,getdate(),100),8,4),'  ',' ')
       END ReportHeadingText,
       'Today''s Business - ' + CASE WHEN DATEPART(HOUR, GETDATE()) < 7  
                                          THEN Replace(Substring(convert(varchar,getdate()-1,100),1,6)+', '+Substring(convert(varchar,getdate()-1,100),8,4),'  ',' ')
                                     ELSE Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,getdate(),100),8,4),'  ',' ')
                                END TodaysBusiness_DateHeader,
       COUNT(DISTINCT MS.MembershipID) TodaysBusiness_NewMembershipCount,
       0 TodaysBusiness_MoneyBackCancelCount,
       'DSSR MTD - ' + CASE WHEN (((DATEPART(HOUR, GETDATE()) >= 7) AND DATEPART(DD,GETDATE()) = 1) OR 
                                  ((DATEPART(HOUR, GETDATE())  < 7) AND DATEPART(DD,GETDATE()) = 2))
                                 THEN ''
                            WHEN DATEPART(HOUR, GETDATE()) >= 7
                                 THEN Replace(Substring(convert(varchar,getdate()-1,100),1,6)+', '+Substring(convert(varchar,getdate()-1,100),8,4),'  ',' ')
                            ELSE Replace(Substring(convert(varchar,getdate()-2,100),1,6)+', '+Substring(convert(varchar,getdate()-2,100),8,4),'  ',' ')
                       END DSSRMTD_DateHeader,
       0 DSSRMTD_NewMembershipCount,
       0 DSSRMTD_MoneyBackCancelCount,
       Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,getdate(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ') ReportRunDateTime
FROM vClub C
JOIN #Membership MS
  ON MS.ClubID = C.ClubID
JOIN vValSalesArea VSA
  ON VSA.ValSalesAreaID = C.ValSalesAreaID
WHERE MS.MembershipSalesReportingCategory IN ('DSSR_Express', 'DSSR_Bronze', 'DSSR_Gold', 'DSSR_Platinum','DSSR_BronzeElite', 'DSSR_GoldElite', 'DSSR_PlatinumElite', 'DSSR_Onyx', 'DSSR_Ovation', 'DSSR_Diamond','DSSR_AccessByPricePaid')
  AND Cast(MS.CreatedDateTime As Varchar(11)) = CASE WHEN DatePart(Hour,GetDate()) < 7
                                                          THEN CAST(DATEADD(DD, -1, GETDATE()) AS VARCHAR(11))
                                                     ELSE CAST(GETDATE() AS VARCHAR(11)) END
GROUP BY VSA.Description, C.ClubName

UNION ALL

--Query #2 - Today’s 30 Day Cancellations 
SELECT ISNULL(VSA.Description, 'None Designated') SalesAreaName,
       C.ClubName ClubName,
       CASE WHEN DATEPART(HOUR, GETDATE()) < 7 
                 THEN 'Report through Midnight ' + Replace(Substring(convert(varchar,getdate()-1,100),1,6)+', '+Substring(convert(varchar,getdate()-1,100),8,4),'  ',' ')
            ELSE Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,getdate(),100),8,4),'  ',' ')
       END ReportHeadingText,
       'Today''s Business - ' + CASE WHEN DATEPART(HOUR, GETDATE()) < 7  
                                          THEN Replace(Substring(convert(varchar,getdate()-1,100),1,6)+', '+Substring(convert(varchar,getdate()-1,100),8,4),'  ',' ')
                                     ELSE Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,getdate(),100),8,4),'  ',' ')
                                END TodaysBusiness_DateHeader,
	   0 TodaysBusiness_NewMembershipCount,
	   COUNT(DISTINCT MS.MembershipID) TodaysBusiness_MoneyBackCancelCount,
       'DSSR MTD - ' + CASE WHEN (((DATEPART(HOUR, GETDATE()) >= 7) AND DATEPART(DD,GETDATE()) = 1) OR 
                                  ((DATEPART(HOUR, GETDATE())  < 7) AND DATEPART(DD,GETDATE()) = 2))
                                 THEN ''
                            WHEN DATEPART(HOUR, GETDATE()) >= 7
                                 THEN Replace(Substring(convert(varchar,getdate()-1,100),1,6)+', '+Substring(convert(varchar,getdate()-1,100),8,4),'  ',' ')
                            ELSE Replace(Substring(convert(varchar,getdate()-2,100),1,6)+', '+Substring(convert(varchar,getdate()-2,100),8,4),'  ',' ')
                       END DSSRMTD_DateHeader,
       0 DSSRMTD_NewMembershipCount,
       0 DSSRMTD_MoneyBackCancelCount,
       Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,getdate(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ') ReportRunDateTime
FROM vClub C
JOIN #Membership MS
  ON MS.ClubID = C.ClubID
JOIN vValTerminationReason  VTR
  ON VTR.ValTerminationReasonID = MS.ValTerminationReasonID
JOIN vValSalesArea VSA
  ON VSA.ValSalesAreaID = C.ValSalesAreaID
WHERE MS.MembershipSalesReportingCategory IN ('DSSR_Express', 'DSSR_Bronze', 'DSSR_Gold', 'DSSR_Platinum','DSSR_BronzeElite', 'DSSR_GoldElite', 'DSSR_PlatinumElite', 'DSSR_Onyx', 'DSSR_Ovation', 'DSSR_Diamond','DSSR_AccessByPricePaid')
  AND VTR.ValTerminationReasonID IN (21, 41, 42, 59)
  AND Cast(MS.ExpirationDate As Varchar(11)) = CASE WHEN DatePart(Hour,GetDate()) < 7
                                                          THEN CAST(DATEADD(DD, -1, GETDATE()) AS VARCHAR(11))
                                                     ELSE CAST(GETDATE() AS VARCHAR(11)) END
GROUP BY VSA.Description, C.ClubName


DROP TABLE #Membership
END



