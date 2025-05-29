// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MovieRecommendationSystem {
    
    struct Movie {
        uint256 id;
        string title;
        string genre;
        uint256 releaseYear;
        uint256 totalRatings;
        uint256 averageRating;
        bool exists;
    }
    
    struct User {
        address userAddress;
        mapping(uint256 => uint256) movieRatings; // movieId => rating (1-5)
        uint256[] ratedMovies;
        bool exists;
    }
    
    struct Rating {
        address user;
        uint256 movieId;
        uint256 rating;
        string review;
        uint256 timestamp;
    }
    
    mapping(uint256 => Movie) public movies;
    mapping(address => User) public users;
    mapping(uint256 => Rating[]) public movieReviews;
    
    uint256 public movieCount;
    uint256 public totalUsers;
    
    event MovieAdded(uint256 indexed movieId, string title, string genre);
    event MovieRated(address indexed user, uint256 indexed movieId, uint256 rating);
    event RecommendationGenerated(address indexed user, uint256[] recommendedMovies);
    
    modifier onlyRegisteredUser() {
        require(users[msg.sender].exists, "User not registered");
        _;
    }
    
    modifier validRating(uint256 _rating) {
        require(_rating >= 1 && _rating <= 5, "Rating must be between 1 and 5");
        _;
    }
    
    modifier movieExists(uint256 _movieId) {
        require(movies[_movieId].exists, "Movie does not exist");
        _;
    }
    
    // Core Function 1: Add Movie to the platform
    function addMovie(
        string memory _title, 
        string memory _genre, 
        uint256 _releaseYear
    ) external {
        movieCount++;
        
        movies[movieCount] = Movie({
            id: movieCount,
            title: _title,
            genre: _genre,
            releaseYear: _releaseYear,
            totalRatings: 0,
            averageRating: 0,
            exists: true
        });
        
        emit MovieAdded(movieCount, _title, _genre);
    }
    
    // Core Function 2: Rate Movie and add review
    function rateMovie(
        uint256 _movieId, 
        uint256 _rating, 
        string memory _review
    ) external 
        movieExists(_movieId) 
        validRating(_rating) 
    {
        // Register user if not exists
        if (!users[msg.sender].exists) {
            users[msg.sender].userAddress = msg.sender;
            users[msg.sender].exists = true;
            totalUsers++;
        }
        
        // Check if user has already rated this movie
        bool hasRated = false;
        uint256 oldRating = 0;
        
        if (users[msg.sender].movieRatings[_movieId] > 0) {
            hasRated = true;
            oldRating = users[msg.sender].movieRatings[_movieId];
        } else {
            users[msg.sender].ratedMovies.push(_movieId);
        }
        
        users[msg.sender].movieRatings[_movieId] = _rating;
        
        // Update movie's average rating
        Movie storage movie = movies[_movieId];
        
        if (hasRated) {
            // Update existing rating
            uint256 totalRatingScore = movie.averageRating * movie.totalRatings;
            totalRatingScore = totalRatingScore - oldRating + _rating;
            movie.averageRating = totalRatingScore / movie.totalRatings;
        } else {
            // New rating
            uint256 totalRatingScore = movie.averageRating * movie.totalRatings + _rating;
            movie.totalRatings++;
            movie.averageRating = totalRatingScore / movie.totalRatings;
        }
        
        // Add review
        movieReviews[_movieId].push(Rating({
            user: msg.sender,
            movieId: _movieId,
            rating: _rating,
            review: _review,
            timestamp: block.timestamp
        }));
        
        emit MovieRated(msg.sender, _movieId, _rating);
    }
    
    // Core Function 3: Get personalized movie recommendations
    function getRecommendations() external onlyRegisteredUser returns (uint256[] memory) {
        User storage user = users[msg.sender];
        uint256[] memory recommendations = new uint256[](5); // Return top 5 recommendations
        uint256 recommendationCount = 0;
        
        // Simple recommendation logic based on genre preferences
        string memory preferredGenre = getMostRatedGenre(msg.sender);
        
        // Find highly rated movies in preferred genre that user hasn't rated
        for (uint256 i = 1; i <= movieCount && recommendationCount < 5; i++) {
            if (movies[i].exists && 
                user.movieRatings[i] == 0 && // User hasn't rated this movie
                movies[i].averageRating >= 4 && // High rating (4+)
                compareStrings(movies[i].genre, preferredGenre)) {
                
                recommendations[recommendationCount] = i;
                recommendationCount++;
            }
        }
        
        // If not enough recommendations from preferred genre, add other high-rated movies
        if (recommendationCount < 5) {
            for (uint256 i = 1; i <= movieCount && recommendationCount < 5; i++) {
                if (movies[i].exists && 
                    user.movieRatings[i] == 0 && 
                    movies[i].averageRating >= 4) {
                    
                    bool alreadyAdded = false;
                    for (uint256 j = 0; j < recommendationCount; j++) {
                        if (recommendations[j] == i) {
                            alreadyAdded = true;
                            break;
                        }
                    }
                    
                    if (!alreadyAdded) {
                        recommendations[recommendationCount] = i;
                        recommendationCount++;
                    }
                }
            }
        }
        
        emit RecommendationGenerated(msg.sender, recommendations);
        return recommendations;
    }
    
    // Helper function to get user's most rated genre
    function getMostRatedGenre(address _user) internal view returns (string memory) {
        User storage user = users[_user];
        
        // Simple logic: return genre of the highest rated movie by user
        string memory topGenre = "";
        uint256 highestRating = 0;
        
        for (uint256 i = 0; i < user.ratedMovies.length; i++) {
            uint256 movieId = user.ratedMovies[i];
            uint256 userRating = user.movieRatings[movieId];
            
            if (userRating > highestRating) {
                highestRating = userRating;
                topGenre = movies[movieId].genre;
            }
        }
        
        return topGenre;
    }
    
    // Helper function to compare strings
    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }
    
    // View functions
    function getMovie(uint256 _movieId) external view returns (
        string memory title,
        string memory genre,
        uint256 releaseYear,
        uint256 totalRatings,
        uint256 averageRating
    ) {
        require(movies[_movieId].exists, "Movie does not exist");
        Movie memory movie = movies[_movieId];
        return (movie.title, movie.genre, movie.releaseYear, movie.totalRatings, movie.averageRating);
    }
    
    function getUserRating(address _user, uint256 _movieId) external view returns (uint256) {
        return users[_user].movieRatings[_movieId];
    }
    
    function getMovieReviews(uint256 _movieId) external view returns (Rating[] memory) {
        return movieReviews[_movieId];
    }
    
    function getUserRatedMovies(address _user) external view returns (uint256[] memory) {
        return users[_user].ratedMovies;
    }
}
