*** Settings ***

Resource        cumulusci/robotframework/Salesforce.robot
Suite Teardown  Delete Session Records
Force Tags      api  no-browser

*** Keywords ***

Create Contact
    ${first_name} =  Get fake data  first_name
    ${last_name} =   Get fake data  last_name
    ${contact_id} =  Salesforce Insert  Contact  FirstName=${first_name}  LastName=${last_name}
    &{contact} =  Salesforce Get  Contact  ${contact_id}
    [return]  &{contact}

*** Test Cases ***

Salesforce Delete
    &{contact} =  Create Contact
    Salesforce Delete  Contact  ${contact}[Id]
    &{result} =  SOQL Query  Select Id from Contact WHERE Id = '${contact}[Id]'
    Should Be Equal  ${result}[totalSize]  ${0}

Salesforce Insert
    ${first_name} =  Get fake data  first_name
    ${last_name} =   Get fake data  last_name
    ${contact_id} =  Salesforce Insert  Contact
    ...  FirstName=${first_name}
    ...  LastName=${last_name}
    &{contact} =  Salesforce Get  Contact  ${contact_id}
    Should Be Equal  ${contact}[FirstName]  ${first_name}
    Should Be Equal  ${contact}[LastName]  ${last_name}

Salesforce Update
    &{contact} =  Create Contact
    ${new_last_name} =  Get fake data  last_name
    Salesforce Update  Contact  ${contact}[Id]  LastName=${new_last_name}
    &{contact} =  Salesforce Get  Contact  ${contact}[Id]
    Should Be Equal  ${contact}[LastName]  ${new_last_name}

Salesforce Query
    &{new_contact} =  Create Contact
    @{records} =  Salesforce Query  Contact
    ...              select=Id,FirstName,LastName
    ...              Id=${new_contact}[Id]
    &{contact} =  Get From List  ${records}  0
    Should Be Equal  ${contact}[Id]  ${new_contact}[Id]
    Should Be Equal  ${contact}[FirstName]  ${new_contact}[FirstName]
    Should Be Equal  ${contact}[LastName]  ${new_contact}[LastName]

Salesforce Query Where
    &{new_contact} =  Create Contact
    @{records} =  Salesforce Query  Contact
    ...              select=Id,FirstName,LastName
    ...              where=FirstName='${new_contact}[FirstName]' AND LastName='${new_contact}[LastName]'
    &{contact} =  Get From List  ${records}  0
    Should Be Equal  ${contact}[Id]  ${new_contact}[Id]
    Should Be Equal  ${contact}[FirstName]  ${new_contact}[FirstName]
    Should Be Equal  ${contact}[LastName]  ${new_contact}[LastName]

Salesforce Query Where Plus Clauses
    &{new_contact} =  Create Contact
    @{records} =  Salesforce Query  Contact
    ...              select=Id,FirstName,LastName
    ...              where=LastName='${new_contact}[LastName]'
    ...              FirstName=${new_contact}[FirstName]
    &{contact} =  Get From List  ${records}  0
    Should Be Equal  ${contact}[Id]  ${new_contact}[Id]
    Should Be Equal  ${contact}[FirstName]  ${new_contact}[FirstName]
    Should Be Equal  ${contact}[LastName]  ${new_contact}[LastName]

Salesforce Query Where Not Equal
    &{new_contact} =  Create Contact
    @{records} =  Salesforce Query  Contact
    ...              select=Id,FirstName,LastName
    ...              where= LastName!='${new_contact}[LastName]'
    ...              Id=${new_contact}[Id]
    ${cnt}=    Get length    ${records}
    Should Be Equal As Numbers   ${cnt}  0

Salesforce Query Where Limit Order
    &{anon_contact} =  Create Contact
    &{anon_contact} =  Create Contact
    ${contact_id} =  Salesforce Insert  Contact  FirstName=xyzzy   LastName=xyzzy
    @{records} =    Salesforce Query  Contact
    ...              select=Id,FirstName,LastName
    ...              where= LastName!='xyzzy'
    ...              order_by=LastName desc
    ...              limit=2
    ${cnt}=    Get length    ${records}
    Should Be Equal As Numbers   ${cnt}  2


SOQL Query
    &{new_contact} =  Create Contact
    &{result} =  Soql Query  Select Id, FirstName, LastName from Contact WHERE Id = '${new_contact}[Id]'
    @{records} =  Get From Dictionary  ${result}  records
    &{contact} =  Get From List  ${records}  0
    Should Be Equal  ${result}[totalSize]  ${1}
    Should Be Equal  ${contact}[FirstName]  ${new_contact}[FirstName]
    Should Be Equal  ${contact}[LastName]  ${new_contact}[LastName]

Salesforce Delete Session Records
    [Documentation]
    ...  Verify that 'Delete Session Records' deletes all session records
    ...  This verifies that we fixed a bug which resulted in some records
    ...  not being deleted.

    # We'll use this to uniquely identify all records created in this test
    ${random string}=  Generate Random String

    # First, make sure we have no records that match
    @{query}=  Salesforce Query  Contact  LastName=${random string}
    length should be  ${query}  0         Expected the query to return no records, but it returned ${query}

    # Next, create some records
    FOR  ${i}  IN RANGE  5
        ${contact_id} =  Salesforce Insert  Contact
        ...  FirstName=User-${i}
        ...  LastName=${random string}
    END
    @{query}=  Salesforce Query    Contact  LastName=${random string}
    length should be  ${query}  5  Expected the query to return five records, but it returned ${query}

    # Now, call 'Delete Session Records' and verify all five were deleted
    Delete Session Records
    @{query}=  Salesforce Query  Contact
    ...  LastName=${random string}
    length should be  ${query}  0  Expected the query to return 0 records, but it returned ${query}

Collection API Test
    @{objects} =  Generate Test Data  Contact  20
        ...  FirstName=User {{number}}
        ...  LastName={{fake.last_name}}
    @{records} =    Salesforce Collection Insert  ${objects}
    FOR     ${record}   IN  @{records}
        ${new_last_name} =  Get fake data  last_name
        set to dictionary   ${record}   LastName    ${new_last_name}
    END
    Salesforce Collection Update    ${records}

Collection API Errors Test
    @{objects} =  Generate Test Data  Contact  20
        ...  FirstName=User {{number}}
        ...  LastName={{fake.last_name}}
        ...  Xyzzy=qwertz
    Run Keyword And Expect Error   *No such column*Xyzzy*   Salesforce Collection Insert  ${objects}

    @{objects} =  Generate Test Data  Contact  20
        ...  FirstName=User {{number}}
        ...  LastName=
    Run Keyword And Expect Error   Error*  Salesforce Collection Insert  ${objects}

    @{objects} =  Generate Test Data  Contact  20
        ...  FirstName=User {{number}}
        ...  LastName={{fake.last_name}}
    ${records} =     Salesforce Collection Insert  ${objects}
    FOR     ${record}   IN  @{records}
        set to dictionary   ${record}   Age    Iron
    END
    Run Keyword And Expect Error   *No such column*Age*   Salesforce Collection Update  ${objects}

Get Version
    ${version} =   Get Latest Api Version
    Should Be True     ${version} > 46

Test Elapsed Time For Last Record
    # This test uses contacts as if they were "jobs" because they are
    # easy to insert. I don't currently have a better alternative 
    # for a job-like objects which is easy to create in a vanilla
    # SF org
    ${contact_id} =  Salesforce Insert  Contact  FirstName=Dummy1  LastName=Dummy2
    Log     Noop
    Salesforce Update   Contact     ${contact_id}       LastName=Dummy3
    ${Elapsed}=     Elapsed Time For Last Record    
    ...             obj_name=Contact
    ...             where=Id='${contact_id}'
    ...             start_field=CreatedDate
    ...             end_field=LastModifiedDate
    ...             order_by=LastModifiedDate
    Should Be True      ${Elapsed} > 0

    ${contact2_id} =  Salesforce Insert  Contact  FirstName=Dummy1  LastName=Dummy2
    Salesforce Update   Contact     ${contact_id}       LastName=Dummy3
    ${Elapsed_2}=     Elapsed Time For Last Record    
    ...             obj_name=Contact
    ...             where=Id='${contact_id}'
    ...             start_field=CreatedDate
    ...             end_field=LastModifiedDate
    ...             order_by=LastModifiedDate

    ${Elapsed_latest}=     Elapsed Time For Last Record    
    ...             obj_name=Contact
    ...             start_field=CreatedDate
    ...             end_field=LastModifiedDate
    ...             order_by=LastModifiedDate

    Should Be Equal         ${Elapsed_2}    ${Elapsed_latest}
    Set Test Elapsed Time        ${Elapsed}


Test Elapsed Time For Last Record - Failure
    Run Keyword and expect Error   *Matching record not found*   
    ...     Elapsed Time For Last Record    
    ...             obj_name=AsyncApexJob
    ...             where=ApexClass.Name='BlahBlah'
    ...             start_field=CreatedDate
    ...             end_field=CompletedDate
    ...             order_by=CompletedDate
