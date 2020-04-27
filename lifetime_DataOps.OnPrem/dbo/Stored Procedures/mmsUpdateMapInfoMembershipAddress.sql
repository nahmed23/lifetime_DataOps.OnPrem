


CREATE PROCEDURE [dbo].[mmsUpdateMapInfoMembershipAddress]
								@RowsProcessed int output, 
								@Description  varchar(80) output
AS 

BEGIN
  -- This procedure UPDATES/INSERTS MapInfoMembershipAddress DATA

  SET NOCOUNT ON
  SET XACT_ABORT ON

	DECLARE @LastRunDate DATETIME

        SELECT @LastRunDate = ISNULL(LastProcessedDateTime,GETDATE()-1)
	FROM vLastProcessedDateTime
	WHERE LastProcessedDateTimeID = 2

        --GET ALL UPDATES AND INSERTS SINCE LAST RUN
        SELECT MA.MembershipID,AddressLine1,AddressLine2,City,Zip,ValStateID,MS.ValMembershipStatusID,
               CASE WHEN ISNULL(MS.InsertedDateTime,'1/1/1900')> ISNULL(MS.UpdatedDateTime,'1/1/1900') 
               THEN MS.InsertedDateTime
               ELSE MS.UpdatedDateTime
               END InsUpdDate
        INTO #MembershipAddress
        FROM vMembershipAddress MA JOIN vMembership MS ON MA.MembershipID = MS.MembershipID
        WHERE MS.InsertedDateTime >= @LastRunDate
           OR MS.UpdatedDateTime >= @LastRunDate

       SELECT DISTINCT MA.MembershipID
       INTO #NonAccessMemberships
       FROM #MembershipAddress MA JOIN vMembership MS ON MA.MembershipID = MS.MembershipID
                                  JOIN vProduct P ON MS.MembershipTypeID = P.ProductID
                                  JOIN vMembershipTypeAttribute MTA ON MS.MembershipTypeID = MTA.MembershipTypeID
       WHERE P.Description LIKE '%Flex%' OR P.Description LIKE '%Life Time Health%' OR MTA.ValMembershipTypeAttributeID IN(12,16,17,19)
                             
        --INSERT NEW MEMBERSHIPS
        INSERT INTO vMapInfoMembershipAddress(MembershipID,AddressLine1,AddressLine2,City,StateAbbreviation,Zip,AccessMembershipFlag,CheckInLevel)
        SELECT MA.MembershipID,MA.AddressLine1,MA.AddressLine2,MA.City,LEFT(LTRIM(RTRIM(VA.Abbreviation)),2),MA.Zip,
               CASE WHEN NAM.MembershipID IS NULL THEN 1 ELSE 0 END AS AccessMembershipFlag,MT.ValCheckInGroupID
          FROM #MembershipAddress MA JOIN vValState VA ON MA.ValStateID = VA.ValStateID
                                     LEFT JOIN #NonAccessMemberships NAM ON MA.MembershipID = NAM.MembershipID
                                     LEFT JOIN vMapInfoMembershipAddress MIM ON MIM.MembershipID = MA.MembershipID
                                     JOIN vMembership MS ON MS.MembershipID = MA.MembershipID
                                     JOIN vMembershipType MT ON MT.MembershipTypeID = MS.MembershipTypeID
         WHERE MIM.MembershipID IS NULL AND MA.ValMembershipStatusID <> 1


       --DELETE TERMINATED MEMBERSHIPS

         DELETE vMapInfoMembershipAddress
         FROM vMapInfoMembershipAddress  MIMA JOIN vMembership MA ON MIMA.MembershipID = MA.MembershipID
         WHERE MA.ValMembershipStatusID = 1

         --UPDATE CHANGES
         UPDATE vMapInfoMembershipAddress
            SET AddressLine1 = MA.AddressLine1,
                AddressLine2 = MA.AddressLine2,
                City = MA.City,
                StateAbbreviation = LEFT(LTRIM(RTRIM(VA.Abbreviation)),2),
                Zip = MA.Zip,
                Latitude = NULL,
                Longitude = NULL,
                GeoResults = NULL,
                AccessMembershipFlag = CASE WHEN NAM.MembershipID IS NULL THEN 1 ELSE 0 END,
                CheckInLevel = MT.ValCheckInGroupID
          FROM vMapInfoMembershipAddress MIM JOIN #MembershipAddress MA ON  MIM.MembershipID = MA.MembershipID
                                             JOIN vValState VA ON MA.ValStateID = VA.ValStateID
                                             LEFT JOIN #NonAccessMemberships NAM ON MA.MembershipID = NAM.MembershipID
                                             JOIN vMembership MS ON MS.MembershipID = MA.MembershipID
											 JOIN vMembershipType MT ON MT.MembershipTypeID = MS.MembershipTypeID
          WHERE MA.ValMembershipStatusID <> 1

      UPDATE vLastProcessedDateTime
         SET LastProcessedDateTime = (SELECT DATEADD(dd,-1,MAX(InsUpdDate)) FROM #MembershipAddress)
       WHERE LastProcessedDateTimeID = 2
	
	
     SELECT @RowsProcessed = COUNT(*) FROM #MembershipAddress
     SELECT @Description = 'Number of updates in MapInfoMembershipAddress'
	
	DROP TABLE #MembershipAddress
	DROP TABLE #NonAccessMemberships
END


