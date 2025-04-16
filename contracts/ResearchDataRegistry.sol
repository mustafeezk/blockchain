// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/**
 * @title Research Data Registry
 * @dev Stores and verifies research data hashes on the blockchain
 */
contract ResearchDataRegistry {
    // Role management
    address public owner;
    mapping(address => bool) public researchers;
    
    // Research data structure
    struct ResearchData {
        string title;
        string description;
        string[] authors;
        string dataHash; // Hash of the research data file
        uint256 timestamp;
        address researcher;
        bool isValid;
        string metadataURI; // Link to additional metadata (could be IPFS URI)
    }
    
    // Storage
    mapping(bytes32 => ResearchData) public researchEntries;
    bytes32[] public researchIds;
    
    // Track research by researcher
    mapping(address => bytes32[]) private researcherToEntries;
    
    // Events
    event ResearchRegistered(bytes32 indexed researchId, string title, address researcher);
    event ResearchRevoked(bytes32 indexed researchId, address revoker);
    event ResearcherAdded(address researcher);
    event ResearcherRemoved(address researcher);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }
    
    modifier onlyResearcher() {
        require(researchers[msg.sender] || msg.sender == owner, "Only authorized researchers can call this function");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        researchers[msg.sender] = true; // Owner is also a researcher by default
    }
    
    /**
     * @dev Adds a new researcher
     * @param _researcher Address of the new researcher
     */
    function addResearcher(address _researcher) external onlyOwner {
        require(_researcher != address(0), "Invalid address");
        require(!researchers[_researcher], "Address is already a researcher");
        
        researchers[_researcher] = true;
        emit ResearcherAdded(_researcher);
    }
    
    /**
     * @dev Removes a researcher
     * @param _researcher Address of the researcher to remove
     */
    function removeResearcher(address _researcher) external onlyOwner {
        require(researchers[_researcher], "Address is not a researcher");
        require(_researcher != owner, "Cannot remove owner as researcher");
        
        researchers[_researcher] = false;
        emit ResearcherRemoved(_researcher);
    }
    
    /**
     * @dev Register new research data
     * @param _title Title of the research
     * @param _description Brief description of the research
     * @param _authors List of authors of the research
     * @param _dataHash Hash of the research data file
     * @param _metadataURI URI pointing to additional metadata
     * @return researchId Unique ID for this research entry
     */
    function registerResearch(
        string memory _title,
        string memory _description,
        string[] memory _authors,
        string memory _dataHash,
        string memory _metadataURI
    ) external onlyResearcher returns (bytes32) {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_dataHash).length > 0, "Data hash cannot be empty");
        require(_authors.length > 0, "At least one author is required");
        
        // Generate a unique ID for this research
        bytes32 researchId = keccak256(abi.encodePacked(
            _title,
            _dataHash,
            msg.sender,
            block.timestamp
        ));
        
        // Ensure this ID is not already used
        require(researchEntries[researchId].researcher == address(0), "Research ID already exists");
        
        // Store the research data
        researchEntries[researchId] = ResearchData({
            title: _title,
            description: _description,
            authors: _authors,
            dataHash: _dataHash,
            timestamp: block.timestamp,
            researcher: msg.sender,
            isValid: true,
            metadataURI: _metadataURI
        });
        
        researchIds.push(researchId);
        researcherToEntries[msg.sender].push(researchId);
        
        emit ResearchRegistered(researchId, _title, msg.sender);
        
        return researchId;
    }
    
    /**
     * @dev Revoke a research entry (e.g., in case of fraud or error)
     * @param _researchId ID of the research to revoke
     */
    function revokeResearch(bytes32 _researchId) external {
        require(researchEntries[_researchId].researcher != address(0), "Research does not exist");
        require(researchEntries[_researchId].isValid, "Research is already revoked");
        // Only the original researcher or the contract owner can revoke
        require(
            researchEntries[_researchId].researcher == msg.sender || msg.sender == owner,
            "Only the researcher or owner can revoke this research"
        );
        
        researchEntries[_researchId].isValid = false;
        
        emit ResearchRevoked(_researchId, msg.sender);
    }
    
    /**
     * @dev Verify research by its ID
     * @param _researchId ID of the research to verify
     * @return isValid Whether the research entry is valid
     * @return research The research data
     */
    function verifyResearch(bytes32 _researchId) 
        external 
        view 
        returns (bool isValid, ResearchData memory research) 
    {
        research = researchEntries[_researchId];
        require(research.researcher != address(0), "Research does not exist");
        
        return (research.isValid, research);
    }
    
    /**
     * @dev Verify research by its data hash
     * @param _dataHash Hash of the research data file
     * @return found Whether research with this hash exists
     * @return researchId The ID of the research if found
     */
    function verifyResearchByHash(string memory _dataHash) 
        external 
        view 
        returns (bool found, bytes32 researchId) 
    {
        for (uint i = 0; i < researchIds.length; i++) {
            bytes32 id = researchIds[i];
            if (keccak256(abi.encodePacked(researchEntries[id].dataHash)) == 
                keccak256(abi.encodePacked(_dataHash))) {
                return (true, id);
            }
        }
        
        return (false, 0);
    }
    
    /**
     * @dev Get all research entries by a specific researcher
     * @param _researcher Address of the researcher
     * @return Array of research IDs belonging to this researcher
     */
    function getResearchByResearcher(address _researcher) 
        external 
        view 
        returns (bytes32[] memory) 
    {
        return researcherToEntries[_researcher];
    }
    
    /**
     * @dev Get the total number of research entries
     * @return The count of research entries
     */
    function getResearchCount() external view returns (uint256) {
        return researchIds.length;
    }
    
    /**
     * @dev Get research ID at a specific index
     * @param _index The index to look up
     * @return The research ID at that index
     */
    function getResearchIdAtIndex(uint256 _index) external view returns (bytes32) {
        require(_index < researchIds.length, "Index out of bounds");
        return researchIds[_index];
    }
    
    /**
     * @dev Transfer ownership of the contract
     * @param _newOwner Address of the new owner
     */
    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid address");
        owner = _newOwner;
    }
}