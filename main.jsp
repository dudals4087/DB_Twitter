<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"
         import="java.util.*, java.sql.*, java.text.SimpleDateFormat" %>
<%@ include file="dbconn.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");
    String currentUser = (String) session.getAttribute("currentUser");
    Boolean currentPaid = (Boolean) session.getAttribute("currentUserPaid");
    if(currentPaid == null) currentPaid = false;

    // --- [기존 로직] ---
    Set<String> myFollowings = new HashSet<>();
    if(currentUser!=null){
        try(PreparedStatement fps=con.prepareStatement("SELECT follower_id FROM followings WHERE user_id=?")){
            fps.setString(1,currentUser);
            try(ResultSet frs=fps.executeQuery()){ while(frs.next()) myFollowings.add(frs.getString(1)); }
        }catch(Exception e){}
    }

    String myStatus=null; String myPaidStr=null; String myPrivateStr="F";
    String myProfileImg=null; // 내 프로필 이미지 변수

    if(currentUser!=null){
        // 내 정보 조회 (profile_img 포함)
        try(PreparedStatement ps=con.prepareStatement("SELECT status_message, paid, is_private, profile_img FROM users WHERE user_id=?")){
            ps.setString(1,currentUser);
            try(ResultSet rs=ps.executeQuery()){
                if(rs.next()){ 
                    myStatus=rs.getString(1); 
                    myPaidStr=rs.getString(2); 
                    myPrivateStr=rs.getString(3); 
                    myProfileImg=rs.getString(4); // 이미지 가져오기
                    if(myPrivateStr==null)myPrivateStr="F"; 
                }
            }
        }catch(Exception e){}
    }
    boolean myPaid="T".equals(myPaidStr); boolean myPrivate="T".equals(myPrivateStr);

    class SuggestUser { String userId; String status; String paid; String profileImg; }
    List<SuggestUser> suggests = new ArrayList<>();
    if(currentUser!=null){
        // 추천 친구 조회 (profile_img 포함)
        try(PreparedStatement ps=con.prepareStatement("SELECT u.user_id, u.status_message, u.paid, u.profile_img FROM users u WHERE u.user_id<>? AND u.user_id NOT IN (SELECT follower_id FROM followings WHERE user_id=?) ORDER BY RAND() LIMIT 5")){
            ps.setString(1,currentUser); ps.setString(2,currentUser);
            try(ResultSet rs=ps.executeQuery()){
                while(rs.next()){ 
                    SuggestUser su=new SuggestUser(); 
                    su.userId=rs.getString(1); 
                    su.status=rs.getString(2); 
                    su.paid=rs.getString(3); 
                    su.profileImg=rs.getString(4); 
                    suggests.add(su); 
                }
            }
        }catch(Exception e){}
    }

    class TimelinePost {
        String postId; String content; int likes; int commentCount;
        String writerId; String writerStatus; String writerPaid; String writerPrivate;
        String writerProfileImg; 
        String createdAt; boolean isLiked; 
        String imgFile; 
    }
    List<TimelinePost> timeline = new ArrayList<>();

    String postSql = "";
    // 타임라인 쿼리 (profile_img 포함, LIMIT 30)
    if (currentUser == null) {
        postSql = "SELECT p.post_id, p.content, p.num_of_likes, p.created_at, p.img_file, u.user_id, u.status_message, u.paid, u.is_private, u.profile_img, (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.post_id) AS c_count FROM posts p JOIN users u ON u.user_id = p.writer_id WHERE (u.is_private='F' OR u.is_private IS NULL) ORDER BY p.created_at DESC LIMIT 30";
    } else {
        postSql = "SELECT p.post_id, p.content, p.num_of_likes, p.created_at, p.img_file, u.user_id, u.status_message, u.paid, u.is_private, u.profile_img, (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.post_id) AS c_count FROM posts p JOIN users u ON u.user_id = p.writer_id WHERE (u.is_private='F' OR u.is_private IS NULL) OR (p.writer_id=?) OR (p.writer_id IN (SELECT follower_id FROM followings WHERE user_id=?)) ORDER BY p.created_at DESC LIMIT 30";
    }

    try(PreparedStatement ps=con.prepareStatement(postSql)){
        if(currentUser!=null){ ps.setString(1,currentUser); ps.setString(2,currentUser); }
        try(ResultSet rs=ps.executeQuery()){
            while(rs.next()){
                TimelinePost tp=new TimelinePost();
                tp.postId=rs.getString("post_id"); tp.content=rs.getString("content");
                tp.likes=rs.getInt("num_of_likes"); tp.commentCount=rs.getInt("c_count");
                tp.writerId=rs.getString("user_id"); tp.writerStatus=rs.getString("status_message");
                tp.writerPaid=rs.getString("paid"); tp.writerPrivate=rs.getString("is_private");
                tp.writerProfileImg = rs.getString("profile_img"); 
                tp.imgFile = rs.getString("img_file"); 
                
                Timestamp ts=rs.getTimestamp("created_at");
                tp.createdAt=(ts!=null)?new SimpleDateFormat("MM-dd HH:mm").format(ts):"";
                
                tp.isLiked=false;
                if(currentUser!=null){
                    try(PreparedStatement psl=con.prepareStatement("SELECT 1 FROM post_likes WHERE post_id=? AND liker_id=?")){
                        psl.setString(1,tp.postId); psl.setString(2,currentUser);
                        try(ResultSet rsl=psl.executeQuery()){ if(rsl.next()) tp.isLiked=true; }
                    }
                }
                timeline.add(tp);
            }
        }
    }catch(Exception e){ e.printStackTrace(); }
    String currentInitial=(currentUser!=null&&currentUser.length()>0)?currentUser.substring(0,1).toUpperCase():"G";
%>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>TWITTER_DB4</title>
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@800&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="style.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <style>
        .home-layout { display:flex; justify-content:center; gap:16px; margin-top:16px; }
        .home-main { flex:0 0 680px; max-width:680px; }
        .home-side { flex:0 0 350px; max-width:350px; }
        @media(max-width:960px){ .home-layout{flex-direction:column;} .home-main,.home-side{flex:1 1 auto; max-width:100%; margin:0 8px;} }
        
        .post-input-textarea { width:100%; border:none; padding:10px 0; font-size:16px; resize:none; min-height:80px; outline:none; }
        .post-input-footer { display:flex; justify-content:space-between; align-items:center; border-top:1px solid #eff3f4; padding-top:10px; margin-top:10px; }
        
        .file-upload-label { cursor:pointer; color:#1d9bf0; font-size:18px; padding:8px; border-radius:50%; transition:0.2s; }
        .file-upload-label:hover { background-color:rgba(29,155,240,0.1); }
        .post-image { width:100%; border-radius:16px; margin-top:12px; border:1px solid #cfd9de; max-height: 500px; object-fit: cover; }
        
        .fa-solid.fa-heart { color:#f91880; }
        .post-actions-row { display:flex; align-items:center; gap:8px; margin-top:8px; }
        .comment-inline-form { display:flex; flex:1; gap:8px; margin:0; }
        .comment-input { flex:1; }

        .avatar-sm-img {
            width: 40px; height: 40px; 
            border-radius: 50%; 
            object-fit: cover; 
            border: 1px solid #cfd9de;
        }
    </style>
</head>
<body>
<div class="app-shell">
    <header class="app-header">
        <div class="app-header-left"><a href="main.jsp" class="app-logo">TWITTER_DB4</a></div>
        <div class="app-header-right">
            <% if(currentUser==null){ %>
                <a href="login.jsp" class="icon-btn" title="로그인"><i class="fa-solid fa-user"></i></a>
            <% }else{ %>
                <a href="followList.jsp" class="icon-btn" title="검색"><i class="fa-solid fa-magnifying-glass"></i></a>
                
                <a href="profile.jsp" class="icon-btn" title="내 프로필" style="padding:0; display:flex; align-items:center; justify-content:center; overflow:hidden;">
                    <% if(myProfileImg != null && !myProfileImg.isEmpty()) { %>
                        <img src="uploads/<%= myProfileImg %>" style="width:100%; height:100%; border-radius:50%; object-fit:cover;">
                    <% } else { %>
                        <%= currentInitial %>
                    <% } %>
                </a>

                <a href="settings.jsp" class="icon-btn" title="설정"><i class="fa-solid fa-gear"></i></a>
                <a href="messages.jsp" class="icon-btn" title="메시지"><i class="fa-regular fa-comments"></i></a>
            <% } %>
        </div>
    </header>

    <div class="home-layout">
        <div class="home-main">
            <div class="card post-input-card">
                <% if(currentUser==null){ %>
                    <div class="helper-text"><a href="login.jsp" class="post-meta-link">로그인</a> 필요</div>
                <% }else{ String myInit=currentUser.substring(0,1).toUpperCase(); %>
                <div style="display:flex; gap:12px;">
                    <a href="profile.jsp" style="text-decoration:none;">
                        <% if(myProfileImg != null && !myProfileImg.isEmpty()) { %>
                            <img src="uploads/<%= myProfileImg %>" class="avatar-sm-img">
                        <% } else { %>
                            <div class="avatar-sm"><%= myInit %></div>
                        <% } %>
                    </a>
                    
                    <div style="flex:1;">
                        <form method="post" action="createPost.jsp" enctype="multipart/form-data">
                            <textarea name="content" class="post-input-textarea" placeholder="무슨 일이 일어나고 있나요?" required></textarea>
                            <div class="post-input-footer">
                                <div>
                                    <label for="imgInput" class="file-upload-label" title="사진 추가">
                                        <i class="fa-regular fa-image"></i>
                                    </label>
                                    <input type="file" id="imgInput" name="postImage" accept="image/*" style="display:none;">
                                </div>
                                <button type="submit" class="btn-primary">게시하기</button>
                            </div>
                        </form>
                    </div>
                </div>
                <% } %>
            </div>

            <div class="card">
                <div class="section-title">타임라인</div>
                <% if(timeline.isEmpty()){ %>
                    <div class="helper-text" style="padding:20px; text-align:center;">게시글이 없습니다.</div>
                <% }else{ for(TimelinePost tp : timeline){ 
                    String wid=tp.writerId; String wInit=wid.substring(0,1).toUpperCase(); boolean wPaid="T".equals(tp.writerPaid); %>
                <article class="post-card" id="post-<%= tp.postId %>">
                    <div class="post-header">
                        <div class="post-user">
                            <a href="profile.jsp?user=<%= wid %>" class="avatar-sm-link">
                                <% if(tp.writerProfileImg != null && !tp.writerProfileImg.isEmpty()) { %>
                                    <img src="uploads/<%= tp.writerProfileImg %>" class="avatar-sm-img">
                                <% } else { %>
                                    <div class="avatar-sm"><%= wInit %></div>
                                <% } %>
                            </a>
                            <div>
                                <div class="post-username-row">
                                    <a href="profile.jsp?user=<%= wid %>" class="username-link"><%= wid %></a>
                                    <% if(wPaid){ %><span class="badge-check">✓</span><% } %>
                                    <span style="font-weight:400; color:#536471; font-size:13px; margin-left:6px;">· <%= tp.createdAt %></span>
                                </div>
                                <div class="post-meta"><%= (tp.writerStatus==null)?"":tp.writerStatus %></div>
                            </div>
                        </div>
                    </div>
                    
                    <div class="post-content">
                        <a href="postDetail.jsp?post_id=<%= tp.postId %>" style="color:#0f1419; text-decoration:none;">
                            <%= tp.content %>
                        </a>
                        <% if(tp.imgFile != null && !tp.imgFile.isEmpty()) { %>
                            <img src="uploads/<%= tp.imgFile %>" class="post-image" alt="게시글 이미지">
                        <% } %>
                    </div>

                    <div class="post-actions-bar" style="border:none; padding-top:0;">
                        <div class="post-actions-row" style="width:100%;">
                            <% if(currentUser==null){ %>
                                <button class="post-like-btn-inline"><i class="fa-regular fa-heart"></i></button>
                                <span style="font-size:13px; color:#536471;"><%= tp.likes %></span>
                            <% }else{ %>
                                <form method="post" action="likePost.jsp" style="margin:0; display:inline-flex; align-items:center;">
                                    <input type="hidden" name="post_id" value="<%= tp.postId %>">
                                    <button type="submit" class="post-like-btn-inline">
                                        <% if(tp.isLiked){ %><i class="fa-solid fa-heart"></i><% }else{ %><i class="fa-regular fa-heart"></i><% } %>
                                    </button>
                                    <span style="font-size:13px; color:#536471; margin-left:4px;"><%= tp.likes %></span>
                                </form>
                                <form method="post" action="createComment.jsp" class="comment-inline-form" style="margin-left:10px;">
                                    <input type="hidden" name="post_id" value="<%= tp.postId %>">
                                    <input type="text" name="content" class="comment-input" placeholder="답글" required>
                                    <button type="submit" class="btn-primary btn-sm" style="display:none;">게시</button>
                                </form>
                            <% } %>
                        </div>
                    </div>
                </article>
                <% } } %>
            </div>
        </div>
        <div class="home-side">
            <div class="search-container" style="position:static; padding:0 0 16px 0; background:transparent;">
                <form action="followList.jsp" method="get">
                    <div class="search-bar-wrapper"><i class="fa-solid fa-magnifying-glass search-icon-inside"></i><input type="text" name="searchId" class="search-input-rounded" placeholder="사용자 검색"></div>
                </form>
            </div>
            <div class="card"><div class="section-title">추천 친구</div>
                <% if(!suggests.isEmpty()){ for(SuggestUser su:suggests){ %>
                <div class="user-item">
                    <a href="profile.jsp?user=<%= su.userId %>" class="avatar-sm-link">
                        <% if(su.profileImg != null && !su.profileImg.isEmpty()) { %>
                            <img src="uploads/<%= su.profileImg %>" class="avatar-sm-img">
                        <% } else { %>
                            <div class="avatar-sm"><%= su.userId.substring(0,1).toUpperCase() %></div>
                        <% } %>
                    </a>
                    <div class="user-suggest-main">
                        <div class="user-name-row"><%= su.userId %></div>
                        <div class="user-status"><%= (su.status!=null)?su.status:"" %></div>
                    </div>
                </div>
                <% }} else { %><div class="helper-text">추천할 사용자가 없습니다.</div><% } %>
            </div>
        </div>
    </div>
</div>
</body>
</html>
<% if(con!=null)try{con.close();}catch(Exception e){} %>