# Tokenized Community Bulletin Board System

A decentralized community bulletin board system built on the Stacks blockchain using Clarity smart contracts. This system enables neighborhood communities to post announcements, organize content by categories, manage post expiration, moderate content, and promote local businesses.

## System Architecture

The system consists of five interconnected smart contracts:

### 1. Message Posting Contract (`message-posting.clar`)
- Manages neighborhood announcement submissions
- Handles post creation, editing, and deletion
- Tracks post metadata (author, timestamp, content)
- Implements basic access controls

### 2. Category Organization Contract (`category-organization.clar`)
- Sorts posts by topic and relevance
- Manages category creation and assignment
- Provides filtering and search capabilities
- Maintains category hierarchies

### 3. Expiration Management Contract (`expiration-management.clar`)
- Removes outdated announcements automatically
- Manages post lifespans and renewal
- Implements cleanup mechanisms
- Handles expiration notifications

### 4. Moderation Oversight Contract (`moderation-oversight.clar`)
- Ensures appropriate content standards
- Manages moderator permissions
- Handles content flagging and review
- Implements community governance

### 5. Local Business Contract (`local-business.clar`)
- Promotes community commerce opportunities
- Manages business listings and promotions
- Handles business verification
- Implements promotional features

## Features

- **Decentralized Governance**: Community-driven moderation and decision making
- **Token Integration**: Utility tokens for posting, promoting, and governance
- **Automatic Expiration**: Smart contract-based content lifecycle management
- **Category System**: Organized content discovery and filtering
- **Business Promotion**: Dedicated features for local commerce
- **Content Moderation**: Community-based content quality assurance

## Getting Started

### Prerequisites
- Stacks blockchain development environment
- Clarity smart contract deployment tools
- Node.js for testing framework

### Installation

1. Clone the repository
2. Install dependencies: \`npm install\`
3. Run tests: \`npm test\`
4. Deploy contracts to Stacks testnet/mainnet

### Usage

Each contract can be deployed independently and provides specific functionality:

- Deploy message-posting contract first as the core system
- Add category organization for content structure
- Enable expiration management for automated cleanup
- Implement moderation for content quality
- Add business features for local commerce

## Testing

The system includes comprehensive Vitest-based tests for all contracts:

\`\`\`bash
npm test
\`\`\`

Tests cover:
- Contract deployment and initialization
- Core functionality of each contract
- Edge cases and error handling
- Integration scenarios

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## License

MIT License - see LICENSE file for details

## Support

For questions and support, please open an issue in the repository.
