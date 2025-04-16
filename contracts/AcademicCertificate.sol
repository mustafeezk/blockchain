// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/**
 * @title Academic Certificate
 * @dev Stores and verifies academic certificates on the blockchain
 */
contract AcademicCertificate {
    // Role management
    address public owner;
    mapping(address => bool) public issuers;
    
    // Certificate structure
    struct Certificate {
        string studentName;
        string courseName;
        string issueDate;
        address issuer;
        string certificateHash; // Hash of the actual certificate file
        bool isValid;
        string additionalData; // JSON string with additional metadata
    }
    
    // Storage
    mapping(bytes32 => Certificate) public certificates;
    bytes32[] public certificateIds;
    
    // Events
    event CertificateIssued(bytes32 indexed certificateId, string studentName, string courseName, address issuer);
    event CertificateRevoked(bytes32 indexed certificateId, address revoker);
    event IssuerAdded(address issuer);
    event IssuerRemoved(address issuer);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }
    
    modifier onlyIssuer() {
        require(issuers[msg.sender] || msg.sender == owner, "Only authorized issuers can call this function");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        issuers[msg.sender] = true; // Owner is also an issuer by default
    }
    
    /**
     * @dev Adds a new certificate issuer
     * @param _issuer Address of the new issuer
     */
    function addIssuer(address _issuer) external onlyOwner {
        require(_issuer != address(0), "Invalid address");
        require(!issuers[_issuer], "Address is already an issuer");
        
        issuers[_issuer] = true;
        emit IssuerAdded(_issuer);
    }
    
    /**
     * @dev Removes an issuer
     * @param _issuer Address of the issuer to remove
     */
    function removeIssuer(address _issuer) external onlyOwner {
        require(issuers[_issuer], "Address is not an issuer");
        require(_issuer != owner, "Cannot remove owner as issuer");
        
        issuers[_issuer] = false;
        emit IssuerRemoved(_issuer);
    }
    
    /**
     * @dev Issues a new certificate
     * @param _studentName Name of the student
     * @param _courseName Name of the course completed
     * @param _issueDate Date when the certificate was issued
     * @param _certificateHash Hash of the certificate file (IPFS hash or file hash)
     * @param _additionalData Additional metadata as JSON string
     * @return certificateId Unique ID for this certificate
     */
    function issueCertificate(
        string memory _studentName,
        string memory _courseName,
        string memory _issueDate,
        string memory _certificateHash,
        string memory _additionalData
    ) external onlyIssuer returns (bytes32) {
        require(bytes(_studentName).length > 0, "Student name cannot be empty");
        require(bytes(_courseName).length > 0, "Course name cannot be empty");
        require(bytes(_certificateHash).length > 0, "Certificate hash cannot be empty");
        
        // Generate a unique ID for this certificate
        bytes32 certificateId = keccak256(abi.encodePacked(
            _studentName,
            _courseName,
            _issueDate,
            _certificateHash,
            msg.sender,
            block.timestamp
        ));
        
        // Ensure this ID is not already used
        require(certificates[certificateId].issuer == address(0), "Certificate ID already exists");
        
        // Store the certificate data
        certificates[certificateId] = Certificate({
            studentName: _studentName,
            courseName: _courseName,
            issueDate: _issueDate,
            issuer: msg.sender,
            certificateHash: _certificateHash,
            isValid: true,
            additionalData: _additionalData
        });
        
        certificateIds.push(certificateId);
        
        emit CertificateIssued(certificateId, _studentName, _courseName, msg.sender);
        
        return certificateId;
    }
    
    /**
     * @dev Revoke a certificate (e.g., in case of fraud or error)
     * @param _certificateId ID of the certificate to revoke
     */
    function revokeCertificate(bytes32 _certificateId) external onlyIssuer {
        require(certificates[_certificateId].issuer != address(0), "Certificate does not exist");
        require(certificates[_certificateId].isValid, "Certificate is already revoked");
        // Only the original issuer or the contract owner can revoke
        require(
            certificates[_certificateId].issuer == msg.sender || msg.sender == owner,
            "Only the issuer or owner can revoke this certificate"
        );
        
        certificates[_certificateId].isValid = false;
        
        emit CertificateRevoked(_certificateId, msg.sender);
    }
    
    /**
     * @dev Verify a certificate by its ID
     * @param _certificateId ID of the certificate to verify
     * @return isValid Whether the certificate is valid
     * @return cert The certificate data
     */
    function verifyCertificate(bytes32 _certificateId) 
        external 
        view 
        returns (bool isValid, Certificate memory cert) 
    {
        cert = certificates[_certificateId];
        require(cert.issuer != address(0), "Certificate does not exist");
        
        return (cert.isValid, cert);
    }
    
    /**
     * @dev Verify a certificate by its hash
     * @param _certificateHash Hash of the certificate file
     * @return found Whether a certificate with this hash exists
     * @return certificateId The ID of the certificate if found
     */
    function verifyCertificateByHash(string memory _certificateHash) 
        external 
        view 
        returns (bool found, bytes32 certificateId) 
    {
        for (uint i = 0; i < certificateIds.length; i++) {
            bytes32 id = certificateIds[i];
            if (keccak256(abi.encodePacked(certificates[id].certificateHash)) == 
                keccak256(abi.encodePacked(_certificateHash))) {
                return (true, id);
            }
        }
        
        return (false, 0);
    }
    
    /**
     * @dev Get the total number of certificates issued
     * @return The count of certificates
     */
    function getCertificateCount() external view returns (uint256) {
        return certificateIds.length;
    }
    
    /**
     * @dev Get certificate ID at a specific index
     * @param _index The index to look up
     * @return The certificate ID at that index
     */
    function getCertificateIdAtIndex(uint256 _index) external view returns (bytes32) {
        require(_index < certificateIds.length, "Index out of bounds");
        return certificateIds[_index];
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