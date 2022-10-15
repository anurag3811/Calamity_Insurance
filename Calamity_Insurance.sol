// SPDX-License-Identifier: GPL-3.0


pragma solidity >=0.7.0 <0.9.0;

//This is the oracle code you gave, my code strts from line 86
contract DisasterData {

    address public admin;
    uint public startDay;

    struct SeverityData {
        uint lastUpdatedDay;
        uint[] values;        // 0-100 indicating intensity
    }

    mapping(string => SeverityData) public severity;

    constructor() {
        admin = msg.sender;
        startDay = block.timestamp / 2 minutes;
    }

    function setSeverity(string memory district, uint newSeverity) public {
        require(msg.sender == admin, "Only admin can set data");
        require(newSeverity<=100, "Severity exceeds max value of 100");
        uint currentDay = block.timestamp / 2 minutes;
        
        uint currentValue;
        if(severity[district].lastUpdatedDay != 0) {
            currentValue = severity[district].values[severity[district].values.length-1];
        }
        else {
            SeverityData memory data;
            data.lastUpdatedDay = startDay-1;
            severity[district] = data;
            currentValue = 0;
        }
        for(uint i=severity[district].lastUpdatedDay+1; i<currentDay; i++) {
            severity[district].values.push(currentValue);
        }
        severity[district].values.push(newSeverity);
        severity[district].lastUpdatedDay = currentDay;
    }

    function getSeverityData(string memory district, uint day) public view returns (uint){
        require(severity[district].lastUpdatedDay != 0, "Data not present for location");
        require(startDay <= day, "Day should be greater than startDay");
        if(severity[district].lastUpdatedDay > day) return severity[district].values[day-startDay];
        else return severity[district].values[severity[district].values.length-1];
    }

    function getDistricts() public pure returns (string memory) {
        return "Ahmednagar, Akola, Amravati, Aurangabad, Beed, Bhandara, Buldhana, Chandrapur, Dhule, Gadchiroli, Gondia, Hingoli, Jalgaon, Jalna, Kolhapur, Latur, Mumbai City, Mumbai Suburban, Nagpur, Nanded, Nandurbar, Nashik, Osmanabad, Palghar, Parbhani, Pune, Raigad, Ratnagiri, Sangli, Satara, Sindhudurg, Solapur, Thane, Wardha, Washim, Yavatmal";
    }



    function getAccumulatedSeverity(string memory district) public view returns (uint) {
        require(severity[district].lastUpdatedDay != 0, "Data not present for location");

        if(severity[district].values.length == 0) return 0;
        uint sumSeverity = 0;
        uint totalDays = severity[district].values.length < 10 ? severity[district].values.length : 10;
        for(uint i=severity[district].values.length-totalDays; i<severity[district].values.length; i++) {
            sumSeverity += severity[district].values[i];
        }
        return sumSeverity;
    }

}

interface DisasterInterface  {
     function setSeverity(string memory district, uint newSeverity) external;
    function getSeverityData(string memory district, uint day) external view returns (uint);
     function getDistricts() external pure returns (string memory);

     function getAccumulatedSeverity(string memory district) external view returns (uint);

}





//Explaination of formuala is given on https://docs.google.com/document/d/18j_-KnIRHbbwaVRRujiofTS1sMb4YXmSYL76yWiKvb8/edit?usp=drivesdk by me
contract Insurance{
        address public manager;
        constructor(){
        manager = msg.sender;
    }

    modifier restricted() {
        require(msg.sender == manager);
        _;
    }

    address disaster;       
    function setAddress(address _address) external restricted {     //to connect the two contracts
        disaster = _address;
    }

    bool flag = false;          //when someone claims
    uint claimday;              //when claim is triggered
    address[] public farmers;   //array of all farmers' addresses
    uint totalfarmers = 0;      

    uint divisor;               //will divide the total balance of contract with this
    uint singleshare;           //dont confuse it with traditional 'share' , its just a variable




    struct Record{              // struct to keep transaction records  date & amout bundled together
        uint kab;
        uint kitna;
    }

    struct Farmer{
        string name;
        string district;
        Record[] logs;
        uint length;            //no. of transactions       
        bool insured;
        uint compounded;        // a metric used in the formula
    }


    mapping(address=>Farmer) public map;  // address => Farmer


    function getInsured(string memory name, string memory district) external{
        require(flag==false);                               // claim not triggered
        require(map[msg.sender].insured == false);          // not already insured
        map[msg.sender].name = name;
        map[msg.sender].district = district;
        map[msg.sender].insured = true;
        farmers.push(msg.sender);
        totalfarmers +=1;
    }

    function paypremium() external payable{ 
        require(map[msg.sender].insured==true);     //only insured farmer can call
        require(flag==false);                       //claim not triggered
        Record memory r;                            // a record(date & amount)
        r.kab = block.timestamp / 2 minutes;        //date
        r.kitna = msg.value;                        //amount
        map[msg.sender].logs.push(r);               // pushing record in logs
        map[msg.sender].length +=1;                 //just to get length of array easily
    }

    function getsever(string memory dist) public view returns(uint) {  //return  AccumulatedSeverity
        DisasterInterface d = DisasterInterface(disaster);
        return d.getAccumulatedSeverity(dist);
    }

    function badaamount(address bada,uint dayclaim) public view returns(uint){          //to find summation of (amount x duration) of one farmer       
       uint compoundedamount=0;
                for(uint j=0; j < map[bada].length; j++){
                    compoundedamount += (dayclaim-(map[bada].logs[j].kab))*(map[bada].logs[j].kitna); 
                }
                return compoundedamount; 
    }

   
    function claimbutton() external {                // trigger button : set flag as true and calculate divisor

        require(flag==false);                       //so that its only triggered once
        require(map[msg.sender].insured==true);     //only any insured farmer can trigger
        flag = true;                                //triggered
        claimday = block.timestamp / 2 minutes;     //claimday noted


        //calculations:
        //calculations to know each one's share: share(numerator/divisor)
        //(formula used)
        // farmer would be paid = (sumseverity of his district)*(compounded)*(singleshare: (numerator/divisor)  )
        //explaination


        for(uint i=0;i<totalfarmers;i++){

            if(getsever(map[farmers[i]].district)>500){
              

              uint compoundedamount= badaamount(farmers[i],claimday);
                map[farmers[i]].compounded = compoundedamount;

                divisor+= (getsever(map[farmers[i]].district))*compoundedamount;                    // summation of (AccumulatedSeverity x comounded amount)
            }
        }

    }

    function bal() public view returns(uint){         // incase you want to see balance of contract
        return address(this).balance;
    }

    function seedivisor() public view returns(uint){  //incase u want to see if "claim button works or not"
        return divisor;
    }


    //using below function, farmer would claim the insurance amount that he deserves, its kept for him, he can claim anytime
    function claimable() external {
        require(divisor!=0,"divisor 0 hai");

        require(map[msg.sender].insured==true);
        require(flag==true);
        uint balance = bal();
        uint numerator = (getsever(map[msg.sender].district))*(map[msg.sender].compounded)*(balance);
        uint fraction = numerator/divisor;
        payable(msg.sender).transfer(fraction);      // singleshare x AccumulatedSeverity x compounded
    }

}



// etherscan rinkeby : https://rinkeby.etherscan.io/address/0x4eb1f73FeBC3A868999ec8D34303C85D35C81525