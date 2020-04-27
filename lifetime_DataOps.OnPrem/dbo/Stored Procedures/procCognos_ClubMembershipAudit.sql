



/*  
    =============================================  
    Description:    audit of unauthorized memberships
    Parameters:        ClubIDList        -- Clubname (legacy)
                    
    EXEC procCognos_ClubMembershipAudit '242|14|153|158|227|10|208|149|195|188|217|51|7|176|178|1|177|53|131|160|30|194|35|138'
    =============================================    
*/

CREATE PROC [dbo].[procCognos_ClubMembershipAudit] (
    @ClubIDList VARCHAR(8000)      
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON
IF 1=0 BEGIN
       SET FMTONLY OFF
     END


DECLARE @ReportRunDateTime VARCHAR(21), @HeaderClubList AS VARCHAR(8000)
DECLARE @ReportDate Datetime 
SET @ReportRunDateTime = Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,GETDATE(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ')
SET @ReportDate = getdate()

CREATE TABLE #tmpList (StringField VARCHAR(20))
CREATE TABLE #Clubs (ClubID INT)
  EXEC procParseIntegerList @ClubIDList
  INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
  TRUNCATE TABLE #tmpList

CREATE TABLE #CaregiverMembers (MemberID INT)
  INSERT INTO #CaregiverMembers (MemberID) 
  SELECT MemberID 
    FROM vMemberAttribute 
	Where AttributeValue = 1           ----- field options are 1 or 0 where 1 is "active" for this attribute
	AND ValMemberAttributeTypeID = 2   ----- "Caregiver"

  

  SET @HeaderClubList = STUFF((SELECT ', ' + C.ClubName
                               FROM vClub C
                               JOIN #Clubs tC ON tc.ClubID = c.ClubID       
                               FOR XML PATH('')),1,1,'') 

SELECT ProductID
  INTO #ExcludeProductIDs
  FROM vMembershipType MT
  JOIN vMembershipTypeAttribute MTA
    ON MT.MembershipTypeID = MTA.MembershipTypeID
   AND MTA.ValMembershipTypeAttributeID = 35 -- Life Time health


--*************
CREATE TABLE #NonPrimaryMemberCount (MembershipID INT, MemberCount INT)

INSERT INTO #NonPrimaryMemberCount 
SELECT MS.MembershipID, COUNT(*)
FROM dbo.vMember M
  JOIN dbo.vMembership MS
    ON M.MembershipID = MS.MembershipID
  JOIN dbo.vMembershipType MST
    ON MS.MembershipTypeID = MST.MembershipTypeID    
  JOIN dbo.vProduct P
    ON MST.ProductID = P.ProductID
  JOIN dbo.vClub C
    ON MS.ClubID = C.ClubID
  JOIN #Clubs CS
    ON C.ClubID = CS.ClubID
  JOIN dbo.vValMembershipStatus VMSS
    ON MS.ValMembershipStatusID = VMSS.ValMembershipStatusID
    
    WHERE 
          VMSS.Description IN ('Active', 'Late Activation', 'Non-Paid', 'Non-Paid, Late Activation', 'Pending Termination', 'Suspended')
          AND M.ActiveFlag = 1
          AND M.ValMemberTypeID not in (1,4)
    GROUP BY  MS.MembershipID
    HAVING COUNT(*)>1
    ORDER BY MS.MembershipID
    --***************


SELECT 
VR.Description AS RegionDescription,
C.ClubName,
P.Description AS MembershipTypeDescription, 
M.MemberID,
Convert(Varchar,DATEDIFF(yy,M.DOB,GETDATE()) - CASE WHEN DATEPART(dy,M.DOB) > DATEPART(dy,getdate()) THEN 1 ELSE 0 END) MemberAgeInYears, 
M.DOB, 
M.FirstName,
M.LastName,

CASE WHEN SUBSTRING (VMSTFS.Description,1,6)  = 'Single' AND VMT.Description = 'Partner' THEN 1 
     ELSE 0 
	 END UnauthorizedPartner,
     
CASE WHEN VMT.Description = 'Secondary' AND IsNull(#CM.MemberID,0) <> 0 THEN 0   -----  "Caregiver" Secondary members are excluded from audit 
     WHEN VMT.Description = 'Secondary' AND SUBSTRING (VMSTFS.Description,1,6)  = 'Single' THEN 1 
     WHEN VMT.Description = 'Secondary' AND SUBSTRING(VMSTFS.Description,1,6)  = 'Couple' AND #NPMC.MemberCount > 1 THEN 1  
     WHEN VMT.Description = 'Secondary' AND MST.ValPricingMethodID in(1,2) THEN 
	      CASE WHEN DATEDIFF(MM, M.DOB, GetDate()) > ((20 + 1)*12) THEN 1  ----- greater than max age (in months) for non-"Per Adult" membership type pricing methods
               WHEN DATEDIFF(MM, M.DOB, GetDate()) = ((20 + 1)*12)          ----- equal to Max age (in months) for non-"Per Adult" membership type further evaluated to the date in next line
                AND DATEPART(DD,GetDate()) - DATEPART(DD, M.DOB) >= 0 /* birth date is today or has passed*/ THEN 1 END
     WHEN VMT.Description = 'Secondary' THEN 
	      CASE WHEN DATEDIFF(MM, M.DOB, GetDate()) > ((C.MaxSecondaryAge + 1)*12) THEN 1   ----- greater than Max age (in months) allowed by club
               WHEN DATEDIFF(MM, M.DOB, GetDate()) = ((C.MaxSecondaryAge + 1)*12)          ----- equal to Max age (in months) allowed by club further evaluated to the date in next line
                AND DATEPART(DD,GetDate()) - DATEPART(DD, M.DOB) >= 0 /* birth date is today or has passed*/ THEN 1 END
     ELSE 0 
	 END UnauthorizedSecondary,
     
 CASE WHEN VMT.Description = 'Secondary' AND IsNull(#CM.MemberID,0) <> 0 THEN 0   -----  "Caregiver" Secondary members are excluded from audit 
      WHEN VMT.Description = 'Secondary' AND MST.ValPricingMethodID in(1,2) THEN  
        CASE WHEN DATEDIFF(MM, M.DOB, GetDate()) = (((20 + 1)*12)-1)  
                THEN 1   ---- one month prior to the Max age for non "Per Adult" membership types
             WHEN DATEDIFF(MM, M.DOB, GetDate()) =((20 + 1)*12) 
			    THEN        ---- Max age for non "Per Adult" membership types
                   CASE WHEN DATEPART(DD,GetDate()) - DATEPART(DD, M.DOB) < 0 /* birth date has not passed yet*/ 
				   THEN 1 END 
             WHEN DATEDIFF(MM, M.DOB, GetDate()) = (((20 + 1)*12)-2) 
		        THEN     ---- two months prior to the Max age for non "Per Adult" membership types
                   CASE WHEN DATEPART(DD,GetDate()) - DATEPART(DD, M.DOB) > 0 /* birth date has passed*/ 
				   THEN 1 END 
	     END      
	  WHEN VMT.Description = 'Secondary' THEN  
        CASE WHEN DATEDIFF(MM, M.DOB, GetDate()) = (((C.MaxSecondaryAge + 1)*12)-1)
               THEN 1   ---- one month prior to the Max age allowed by club
             WHEN DATEDIFF(MM, M.DOB, GetDate()) = ((C.MaxSecondaryAge + 1)*12) 
			   THEN         ---- Max age allowed by club in months
                  CASE WHEN DATEPART(DD,GetDate()) - DATEPART(DD, M.DOB) < 0 /* birth date has not passed yet*/ 
				       THEN 1 END 
             WHEN DATEDIFF(MM, M.DOB, GetDate()) = (((C.MaxSecondaryAge + 1)*12)-2) 
			   THEN     ---- two months prior to the Max age allowed by club
                   CASE WHEN DATEPART(DD,GetDate()) - DATEPART(DD, M.DOB) > 0 /* birth date has passed*/ 
				        THEN 1 END
		END                    
     ELSE 0 
	 END SecondaryOnAlert,     

CASE WHEN VMT.Description = 'Secondary' AND IsNull(#CM.MemberID,0) <> 0 
        THEN 0   -----  "Caregiver" Secondary members are excluded from audit 
	 WHEN VMT.Description = 'Secondary' AND MST.ValPricingMethodID in(1,2)    ----- standard pricing
	   THEN  
        CASE WHEN DATEDIFF(MM, M.DOB, GetDate()) = (((20 + 1)*12)-3)
             THEN     ---- three months prior to the Max age for non "Per Adult" membership types
                   CASE WHEN DATEPART(DD,GetDate()) - DATEPART(DD, M.DOB) >= 0 /* birth date is today or passed*/ 
				        THEN 1 END 
             WHEN DATEDIFF(MM, M.DOB, GetDate()) = (((20 + 1)*12)-2) 
			 THEN     ---- two months prior to the Max age for non "Per Adult" membership types
                   CASE WHEN DATEPART(DD,GetDate()) - DATEPART(DD, M.DOB) <= 0 /* birth date is today or not passed yet*/ 
				        THEN 1 END                
       END   
     WHEN VMT.Description = 'Secondary'  THEN  
       CASE WHEN DATEDIFF(MM, M.DOB, GetDate()) = (((C.MaxSecondaryAge + 1)*12)-3)   ----- Per-Adult pricing
            THEN     ---- three months prior to the Max age allowed by club
               CASE WHEN DATEPART(DD,GetDate()) - DATEPART(DD, M.DOB) >= 0 /* birth date is today or passed*/ 
			        THEN 1 END 
            WHEN DATEDIFF(MM, M.DOB, GetDate()) = (((C.MaxSecondaryAge + 1)*12)-2) 
		    THEN     ---- two months prior to the Max age allowed by club
               CASE WHEN DATEPART(DD,GetDate()) - DATEPART(DD, M.DOB) <= 0 /* birth date is today or not passed yet*/ 
			        THEN 1 END                
       END     
     ELSE 0 END SecondarySendLetterFlag,      
     
CASE WHEN VMT.Description = 'Junior' AND MST.ValPricingMethodID in(1,2) 
     THEN  
     CASE WHEN DATEDIFF(MM, M.DOB, GetDate()) > ((11 + 1)*12) 
	      THEN 1  ---- The Max age allowed for non "Per Adult" membership types
          WHEN DATEDIFF(MM, M.DOB, GetDate()) = ((11 + 1)*12) AND DATEPART(DD,GetDate()) - DATEPART(DD, M.DOB) >= 0 /* birth date is today or has passed*/ 
		  THEN 1 
     END 
WHEN VMT.Description = 'Junior' THEN  
     CASE WHEN DATEDIFF(MM, M.DOB, GetDate()) > ((C.MaxJuniorAge + 1)*12) 
	      THEN 1  ---- The Max age allowed by club in months
          WHEN DATEDIFF(MM, M.DOB, GetDate()) = ((C.MaxJuniorAge + 1)*12) AND DATEPART(DD,GetDate()) - DATEPART(DD, M.DOB) >= 0 /* birth date is today or has passed*/ 
		  THEN 1 
     END                
     ELSE 0 END UnauthorizedJunior,


CASE WHEN VMT.Description = 'Junior' AND MST.ValPricingMethodID in(1,2)
     THEN  
       CASE WHEN DATEDIFF(MM, M.DOB, GetDate()) = (((11 + 1)*12)-1)
            THEN 1   ---- one month prior to the Max age allowed for non "Per Adult" membership types
            WHEN DATEDIFF(MM, M.DOB, GetDate()) = ((11 + 1)*12) 
			THEN       --- The Max age allowed for non "Per Adult" membership types
              CASE WHEN DATEPART(DD,GetDate()) - DATEPART(DD, M.DOB) < 0 /* birth date has not passed yet*/ 
				   THEN 1 END 
            WHEN DATEDIFF(MM, M.DOB, GetDate()) =(((11 + 1)*12)-2) 
			THEN    --- two months prior to the Max age allowed for non "Per Adult" membership types
              CASE WHEN DATEPART(DD,GetDate()) - DATEPART(DD, M.DOB) > 0 /* birth date has passed*/ 
				   THEN 1 END                
        END 
     WHEN VMT.Description = 'Junior' THEN  
        CASE WHEN DATEDIFF(MM, M.DOB, GetDate()) = (((C.MaxJuniorAge + 1)*12)-1)
             THEN 1   ---- one month prior to the Max age allowed by club
             WHEN DATEDIFF(MM, M.DOB, GetDate()) = ((C.MaxJuniorAge + 1)*12) 
			 THEN       --- The Max age allowed by club in months
                CASE WHEN DATEPART(DD,GetDate()) - DATEPART(DD, M.DOB) < 0 /* birth date has not passed yet*/ 
				     THEN 1 END 
             WHEN DATEDIFF(MM, M.DOB, GetDate()) = (((C.MaxJuniorAge + 1)*12)-2) 
			 THEN    --- two months prior to the Max age allowed by club
                 CASE WHEN DATEPART(DD,GetDate()) - DATEPART(DD, M.DOB) > 0 /* birth date has passed*/ 
				      THEN 1 END                
        END     
     ELSE 0 
	 END JuniorOnAlert,
     
CASE WHEN VMT.Description = 'Junior' AND MST.ValPricingMethodID in(1,2)
     THEN  
       CASE WHEN DATEDIFF(MM, M.DOB, GetDate()) = (((11 + 1)*12)-3)  
            THEN          --- three months prior to the Max age allowed for non "Per Adult" membership types
              CASE WHEN DATEPART(DD,GetDate()) - DATEPART(DD, M.DOB) >= 0 /* birth date is today or passed*/ 
			       THEN 1 END 
            WHEN DATEDIFF(MM, M.DOB, GetDate()) =(((11 + 1)*12)-2) 
			THEN          --- two months prior to the Max age allowed for non "Per Adult" membership types
              CASE WHEN DATEPART(DD,GetDate()) - DATEPART(DD, M.DOB) <= 0 /* birth date is today or not passed yet*/ 
			       THEN 1 END                
     END  
WHEN VMT.Description = 'Junior' 
     THEN  
       CASE WHEN DATEDIFF(MM, M.DOB, GetDate()) = (((C.MaxJuniorAge + 1)*12)-3)
            THEN          --- three months prior to the Max age allowed by club
               CASE WHEN DATEPART(DD,GetDate()) - DATEPART(DD, M.DOB) >= 0 /* birth date is today or passed*/ 
			        THEN 1 END 
          WHEN DATEDIFF(MM, M.DOB, GetDate()) = (((C.MaxJuniorAge + 1)*12)-2) 
		    THEN          --- two months prior to the Max age allowed by club
               CASE WHEN DATEPART(DD,GetDate()) - DATEPART(DD, M.DOB) <= 0 /* birth date is today or not passed yet*/ 
			        THEN 1 END                
     END     
     ELSE 0 END JuniorSendLetterFlag,
     
   @ReportRunDateTime AS ReportRunDateTime,   
   CAST((DATEDIFF(DAY, M.DOB, GetDate()) / (365.23076923074)*12) AS DECIMAL(8,4)) AS Age_in_Months,
   @HeaderClubList AS HeaderClubList,
   M.MembershipID,
   M.ValMemberTypeID,      
   VMT.Description AS MemberTypeDescription, 
   VMSTFS.Description AS MembershipSizeDescription,
   SUBSTRING (VMSTFS.Description,1,6) AS MembershipSize,       
   M2.LastName PrimaryMemberLastName,    
   M2.FirstName PrimaryMemberFirstName,    
   M2.EmailAddress PrimaryMemberEmailAddress,    
   CASE MCP.ActiveFlag WHEN 1 THEN 'Do Not Solicit' ELSE '' END DoNotMailFlag,
   MA.AddressLine1,
   MA.AddressLine2,
   MA.City,
   VS.Abbreviation AS State,
   MA.Zip,
   VC.Abbreviation AS Country,
   IsNull(C.MarketingClubLevel,'None Designated') as MarketingClubLevel,
   CASE WHEN MST.ValPricingMethodID in(1,2)
        THEN '21st'
		WHEN C.MaxSecondaryAge = 21
		THEN '22nd'
		WHEN C.MaxSecondaryAge = 22
		THEN '23rd'
	    WHEN C.MaxSecondaryAge = 23
		THEN '24th'
	    WHEN C.MaxSecondaryAge = 24
		THEN '25th'
		ELSE Convert(Varchar,(C.MaxSecondaryAge + 1))
		END SecondaryLetterAgeLimitText
          
  INTO #Results     
  FROM dbo.vMember M
  JOIN dbo.vMembership MS
    ON M.MembershipID = MS.MembershipID
  JOIN dbo.vMembershipType MST
    ON MS.MembershipTypeID = MST.MembershipTypeID    
  JOIN dbo.vProduct P
    ON MST.ProductID = P.ProductID
  JOIN dbo.vClub C
    ON MS.ClubID = C.ClubID
  JOIN #Clubs CS
    ON C.ClubID = CS.ClubID
  JOIN dbo.vValMembershipStatus VMSS
    ON MS.ValMembershipStatusID = VMSS.ValMembershipStatusID
  JOIN dbo.vValRegion VR
    ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vValMemberType VMT
    ON M.ValMemberTypeID = VMT.ValMemberTypeID
  JOIN dbo.vValMembershipTypeFamilyStatus VMSTFS 
    ON VMSTFS.ValMembershipTypeFamilyStatusID = MST.ValMembershipTypeFamilyStatusID
  JOIN dbo.vMember M2
    ON MS.MembershipID = M2.MembershipID
  LEFT JOIN vMembershipAddress MA
    ON M2.MembershipID = MA.MembershipID
   AND MA.ValAddressTypeID = 1
  LEFT JOIN vValState VS
    ON MA.ValStateID = VS.ValStateID
  LEFT JOIN vValCountry VC
    ON MA.ValCountryID = VC.ValCountryID
  LEFT JOIN vMembershipCommunicationPreference MCP
    ON M2.MembershipID = MCP.MembershipID
   AND MCP.ValCommunicationPreferenceID = 1
 LEFT JOIN #NonPrimaryMemberCount #NPMC
    ON #NPMC.MembershipID = MS.MembershipID
 LEFT JOIN #CaregiverMembers #CM
    ON M.MemberID = #CM.MemberID
 WHERE VMSS.Description IN ('Active', 'Late Activation', 'Non-Paid', 'Non-Paid, Late Activation', 'Pending Termination', 'Suspended')
   AND M.ActiveFlag = 1
   AND M2.ValMemberTypeID = 1
   AND MST.ProductID NOT IN (SELECT ProductID FROM #ExcludeProductIDs)
   ----- bring back all older than the standard age limit, even though some will be elimininated in the above case logic if they are "Per Adult" type memberships
   AND ((VMT.Description = 'Junior' AND Datediff(mm,M.DOB,GetDate()) >= (((11 + 1)*12)-3) AND Datediff(mm,M.DOB,GetDate()) <= (((11 + 1)*12)-2))  ---- 141 & 142 months for standard clubs   
        OR (VMT.Description = 'Secondary' AND Datediff(mm,M.DOB,GetDate()) >= (((20 + 1)*12)-3)  AND Datediff(mm,M.DOB,GetDate()) <= (((20 + 1)*12)-2) )   ---- 249 & 250 months for standard clubs
        OR (VMT.Description = 'Junior' AND Datediff(mm,M.DOB,GetDate()) > (((11 + 1)*12)-2) AND Datediff(mm,M.DOB,GetDate()) < ((11 + 1)*12) )  ---- 142 & 144 months for standard clubs
        OR (VMT.Description = 'Secondary' AND Datediff(mm,M.DOB,GetDate()) > (((20 + 1)*12)-2)  AND Datediff(mm,M.DOB,GetDate()) < ((20 + 1)*12))     ---- 250 & 252 months for standard clubs
        OR (VMT.Description = 'Junior' AND Datediff(mm,M.DOB,GetDate()) >= ((11 + 1)*12) )                       ---- 144 months for standard clubs
        OR (VMT.Description = 'Secondary' AND Datediff(mm,M.DOB,GetDate()) >= ((20 + 1)*12))                  ---- 252 months for standard clubs
        OR (VMT.Description = 'Secondary' AND Substring(VMSTFS.Description,1,6) = 'Single')
        OR (VMT.Description <> 'Junior' AND Substring(VMSTFS.Description,1,6) = 'Couple')
        OR (VMT.Description = 'Partner' AND Substring(VMSTFS.Description,1,6) = 'Single' ))

  
      
	SELECT  	
	RegionDescription,
	ClubName,
	RegionDescription+' ' + ClubName AS Region_Club,	
	MembershipTypeDescription, 
	MemberID,
	MemberAgeInYears, 
	DOB, 
	FirstName,
	LastName,
	FirstName+' '+LastName AS MemberName,	
	ISNULL(UnauthorizedPartner,0) AS UnauthorizedPartner,
	ISNULL(UnauthorizedSecondary,0) AS UnauthorizedSecondary, 
	ISNULL(SecondaryOnAlert,0) AS SecondaryOnAlert,
	--ISNULL(SecondarySendLetterFlag,0) AS SecondarySendLetterFlag,
	--ISNULL(UnauthorizedJunior,0) AS UnauthorizedJunior,
	--ISNULL(JuniorOnAlert,0) AS JuniorOnAlert,
	--ISNULL(JuniorSendLetterFlag,0) AS JuniorSendLetterFlag,
	
	ReportRunDateTime,
	HeaderClubList,
	Age_in_Months,
    MembershipID,
    ValMemberTypeID,  
	MemberTypeDescription, 
    MembershipSizeDescription,
    MembershipSize,       
    PrimaryMemberLastName,    
    PrimaryMemberFirstName,    
    PrimaryMemberEmailAddress,    
    DoNotMailFlag,
    AddressLine1,
    AddressLine2,
    City,
    State,
    Zip,
    Country,
	CASE WHEN IsNull(AddressLine2,'null') = 'null'
	     THEN AddressLine1
		 ELSE AddressLine1 +'; '+ AddressLine2
		 END StreetAddressForFormLetter,
	CASE WHEN Country = 'USA'
	     THEN City +',  '+ State + '  '+ Zip
		 ELSE City +',  '+ State + '  '+ Zip + '    ' + Country 
    	 END CityAddressForFormLetter,
	CASE WHEN MarketingClubLevel in('Diamond','Onyx')
	     THEN 'Life Time Athletic'
		 ELSE 'Life Time Fitness'
		 End ClubSignatureForFormLetter,
    SecondaryLetterAgeLimitText,
	@ReportDate as ReportRunDate
	FROM #Results 
	WHERE (ISNULL(UnauthorizedPartner,0) + ISNULL(UnauthorizedSecondary,0) + ISNULL(SecondaryOnAlert,0)) > 0
    ORDER BY 	RegionDescription,	ClubName,	MembershipTypeDescription, 	MemberID
 
DROP TABLE #tmpList 
DROP TABLE #Clubs
DROP TABLE #CaregiverMembers
DROP TABLE #ExcludeProductIDs
DROP TABLE #Results
DROP TABLE #NonPrimaryMemberCount


END


