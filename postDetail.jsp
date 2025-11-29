<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"
         import="java.util.*, java.sql.*, java.text.SimpleDateFormat" %>
<%@ include file="dbconn.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");
    String currentUser = (String) session.getAttribute("currentUser");
    
    String postId = request.getParameter("post_id");
    if (postId == null || postId.trim().isEmpty()) {
        response.sendRedirect("main.jsp");
        return;
    }

    String errorMsg = null;
    String content = ""; String writerId = ""; String writerStatus = ""; String writerPaid = "";
    String postDate = ""; int likes = 0; boolean isLiked = false;
    
    // 1. 게시글 정보 조회 (로직 유지)
    try {
        String sql = "SELECT p.content, p.num_of_likes, p.created_at, u.user_id, u.status_message, u.paid FROM posts p JOIN users u ON u.user_id = p.writer_id WHERE p.post_id = ?";
        try (PreparedStatement ps = con.prepareStatement(sql)) {
            ps.setString(1, postId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    content = rs.getString("content"); likes = rs.getInt("num_of_likes");
                    writerId = rs.getString("user_id"); writerStatus = rs.getString("status_message");
                    writerPaid = rs.getString("paid");
                    Timestamp ts = rs.getTimestamp("created_at");
                    if (ts != null) postDate = new SimpleDateFormat("yyyy년 M월 d일 · a h:mm").format(ts);
                } else { errorMsg = "삭제되었거나 존재하지 않는 게시글입니다."; }
            }
        }
        if (currentUser != null && errorMsg == null) {
            String likeCheckSql = "SELECT 1 FROM post_likes WHERE post_id = ? AND liker_id = ?";
            try (PreparedStatement ps = con.prepareStatement(likeCheckSql)) {
                ps.setString(1, postId); ps.setString(2, currentUser);
                try (ResultSet rs = ps.executeQuery()) { if (rs.next()) isLiked = true; }
            }
        }
    } catch (Exception e) { e.printStackTrace(); errorMsg = "게시글을 불러오는 중 오류가 발생했습니다."; }

    // [NEW] 2. 대댓글 목록 사전 조회 및 그룹화
    // Map<부모댓글ID, List<답글>>
    Map<String, List<Map<String, Object>>> repliesMap = new HashMap<>();
    try {
        // replies 테이블에서 해당 post의 모든 댓글에 대한 답글을 가져옴
        String rSql = "SELECT r.comment_id, r.content, r.writer_id, u.paid, r.created_at FROM replies r JOIN users u ON u.user_id = r.writer_id WHERE r.comment_id IN (SELECT comment_id FROM comments WHERE post_id = ?) ORDER BY r.created_at ASC"; 
        try (PreparedStatement ps = con.prepareStatement(rSql)) {
            ps.setString(1, postId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    String parentId = rs.getString("comment_id");
                    Map<String, Object> reply = new HashMap<>();
                    reply.put("writer", rs.getString("writer_id"));
                    reply.put("content", rs.getString("content"));
                    reply.put("paid", rs.getString("paid"));
                    reply.put("date", new SimpleDateFormat("MM.dd a h:mm").format(rs.getTimestamp("created_at")));
                    
                    repliesMap.computeIfAbsent(parentId, k -> new ArrayList<>()).add(reply);
                }
            }
        }
    } catch (Exception e) { e.printStackTrace(); }


    // 3. 댓글 목록 조회 (comments table - level 1)
    List<Map<String,Object>> comments = new ArrayList<>();
    try {
        String cSql = "SELECT c.comment_id, c.content, c.writer_id, c.num_of_likes, u.paid FROM comments c JOIN users u ON u.user_id = c.writer_id WHERE c.post_id = ? ORDER BY c.comment_id ASC";
        try (PreparedStatement ps = con.prepareStatement(cSql)) {
            ps.setString(1, postId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String,Object> map = new HashMap<>();
                    String cid = rs.getString("comment_id");
                    map.put("cid", cid);
                    map.put("content", rs.getString("content"));
                    map.put("writer", rs.getString("writer_id"));
                    map.put("likes", rs.getInt("num_of_likes"));
                    map.put("paid", rs.getString("paid"));
                    
                    // [NEW] 대댓글 리스트 주입
                    map.put("replies", repliesMap.get(cid)); 
                    
                    comments.add(map);
                }
            }
        }
    } catch (Exception e) { e.printStackTrace(); }
%>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>게시물 상세보기</title>
    <link rel="stylesheet" href="style.css">
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@800&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <style>
        .detail-header { display: flex; align-items: center; gap: 20px; padding: 0 16px; height: 53px; position: sticky; top: 0; background: rgba(255,255,255,0.9); backdrop-filter: blur(12px); border-bottom: 1px solid #eff3f4; z-index: 10; }
        .back-btn { border: none; background: transparent; font-size: 18px; cursor: pointer; padding: 8px; border-radius: 50%; transition: 0.2s; color: #0f1419; }
        .back-btn:hover { background-color: #eff3f4; }
        .detail-title { font-size: 20px; font-weight: 700; }
        .big-post { padding: 16px; border-bottom: 1px solid #eff3f4; }
        .big-post-content { font-size: 23px; line-height: 1.4; margin: 20px 0; word-break: break-word; }
        .big-post-meta { color: #536471; font-size: 15px; margin-bottom: 16px; border-bottom: 1px solid #eff3f4; padding-bottom: 16px; }
        .big-post-stats { padding: 16px 0; border-bottom: 1px solid #eff3f4; font-size: 15px; display: flex; gap: 20px; }
        .big-post-actions { padding: 10px 0; border-bottom: 1px solid #eff3f4; display: flex; justify-content: space-around; }
        .action-icon-btn { border: none; background: transparent; font-size: 20px; color: #536471; padding: 8px; border-radius: 50%; cursor: pointer; transition: 0.2s; }
        .action-icon-btn:hover { background-color: rgba(29, 155, 240, 0.1); color: #1d9bf0; }
        .action-icon-btn.danger:hover { background-color: rgba(244, 33, 46, 0.1); color: #f4212e; }
        .fa-solid.fa-heart { color: #f91880; }
        .comment-section { padding-bottom: 100px; }
        .comment-item { padding: 16px; border-bottom: 1px solid #eff3f4; display: flex; gap: 12px; }
        /* [NEW] 대댓글 스타일 */
        .reply-item { padding: 16px 0 0 0; display: flex; gap: 12px; }
        .reply-wrapper { border-left: 2px solid #cfd9de; margin-left: 20px; padding-left: 20px; }
    </style>
</head>
<body>
<div class="app-shell">

    <header class="app-header">
        <div class="app-header-left"><a href="main.jsp" class="app-logo">TWITTER_DB4</a></div>
        <div class="app-header-right"><a href="main.jsp" class="icon-btn"><i class="fa-solid fa-house"></i></a></div>
    </header>

    <div class="main-layout">
        
        <div class="column-center" style="border: none;">
            
            <div class="detail-header">
                <button onclick="history.back()" class="back-btn"><i class="fa-solid fa-arrow-left"></i></button>
                <div class="detail-title">게시물</div>
            </div>

            <% if (errorMsg != null) { %>
                <div style="padding: 40px; text-align: center; color: #536471;"><h3>오류 발생</h3><p><%= errorMsg %></p></div>
            <% } else { 
                String wInit = writerId.substring(0,1).toUpperCase(); boolean wPaid = "T".equals(writerPaid);
            %>
                <div class="big-post">
                    <div style="display:flex; gap:12px; align-items:center;">
                        <a href="profile.jsp?user=<%= writerId %>" class="avatar-sm-link"><div class="avatar-sm" style="width:48px; height:48px;"><%= wInit %></div></a>
                        <div>
                            <div class="post-username-row" style="font-size:16px;">
                                <a href="profile.jsp?user=<%= writerId %>" class="username-link"><%= writerId %></a>
                                <% if (wPaid) { %><span class="badge-check">✓</span><% } %>
                            </div>
                            <div class="post-meta"><%= (writerStatus==null)?"":writerStatus %></div>
                        </div>
                        <% if (currentUser != null && currentUser.equals(writerId)) { %>
                            <div style="margin-left:auto;"><form method="post" action="deletePost.jsp" style="margin:0;"><input type="hidden" name="post_id" value="<%= postId %>"><button type="submit" class="action-icon-btn danger" title="게시글 삭제" onclick="return confirm('정말 삭제하시겠습니까?');"><i class="fa-regular fa-trash-can"></i></button></form></div>
                        <% } %>
                    </div>
                    <div class="big-post-content"><%= content %></div>
                    <div class="big-post-meta"><%= postDate %></div>
                    <div class="big-post-stats">
                        <span><strong><%= likes %></strong> <span style="color:#536471">마음에 들어요</span></span>
                        <span><strong><%= comments.size() %></strong> <span style="color:#536471">댓글</span></span>
                    </div>
                    <div class="big-post-actions">
                        <form method="post" action="likePost.jsp" style="margin:0;"><input type="hidden" name="post_id" value="<%= postId %>"><button type="submit" class="action-icon-btn"><% if (isLiked) { %><i class="fa-solid fa-heart"></i><% } else { %><i class="fa-regular fa-heart"></i><% } %></button></form>
                        <button class="action-icon-btn" onclick="document.getElementById('commentInput').focus()"><i class="fa-regular fa-comment"></i></button>
                    </div>
                </div>

                <% if (currentUser != null) { %>
                <div style="padding: 16px; border-bottom: 1px solid #eff3f4; display:flex; gap:12px;">
                    <div class="avatar-sm"><%= currentUser.substring(0,1).toUpperCase() %></div>
                    <form method="post" action="createComment.jsp" style="flex:1;">
                        <input type="hidden" name="post_id" value="<%= postId %>">
                        <textarea id="commentInput" name="content" class="post-input-textarea" style="min-height:60px; font-size:16px; border:none; border-bottom:1px solid #eff3f4; border-radius:0; padding:10px 0;" placeholder="답글 게시하기" required></textarea>
                        <div style="display:flex; justify-content:flex-end;"><button type="submit" class="btn-primary">답글</button></div>
                    </form>
                </div>
                <% } %>

                <div class="comment-section">
                    <% for (Map<String,Object> c : comments) { 
                        String cWriter = (String) c.get("writer"); String cContent = (String) c.get("content"); String cPaid = (String) c.get("paid");
                        int cLikes = (int) c.get("likes"); String cid = (String) c.get("cid");
                        String cInit = cWriter.substring(0,1).toUpperCase();
                    %>
                    <div class="comment-item">
                        <a href="profile.jsp?user=<%= cWriter %>" class="avatar-sm-link"><div class="avatar-sm"><%= cInit %></div></a>
                        <div style="flex:1;">
                            <div class="post-username-row">
                                <a href="profile.jsp?user=<%= cWriter %>" class="username-link"><%= cWriter %></a>
                                <% if ("T".equals(cPaid)) { %><span class="badge-check">✓</span><% } %>
                                <span style="color:#536471; font-weight:400; font-size:13px; margin-left:4px;">· 댓글</span>
                            </div>
                            <div style="margin-top:4px; font-size:15px; color:#0f1419;"><%= cContent %></div>

                            <div class="post-footer-row" style="margin-top:8px; gap:20px;">
                                <form method="post" action="likeComment.jsp" style="margin:0; display:inline;"><input type="hidden" name="comment_id" value="<%= cid %>"><input type="hidden" name="post_id" value="<%= postId %>"> <button type="submit" style="border:none; background:transparent; cursor:pointer; color:#536471; font-size:13px;"><i class="fa-regular fa-heart"></i> <%= cLikes %></button></form>
                                
                                <% if (currentUser != null) { %>
                                <button type="button" onclick="toggleReplyForm('<%= cid %>')" style="border:none; background:transparent; cursor:pointer; color:#536471; font-size:13px;" title="답글 달기">
                                    <i class="fa-regular fa-comment"></i> 답글
                                </button>
                                <% } %>

                                <% if (currentUser != null && currentUser.equals(cWriter)) { %>
                                    <form method="post" action="deleteComment.jsp" style="margin:0; display:inline;"><input type="hidden" name="comment_id" value="<%= cid %>"><input type="hidden" name="post_id" value="<%= postId %>"><button type="submit" style="border:none; background:transparent; cursor:pointer; color:#536471; font-size:13px;" title="삭제" onclick="return confirm('댓글을 삭제할까요?');"><i class="fa-regular fa-trash-can"></i></button></form>
                                <% } %>
                            </div>
                            
                            <div id="reply-form-<%= cid %>" style="display:none; margin-top:10px; border-top:1px solid #eff3f4; padding-top:10px;">
                                <form method="post" action="createComment.jsp" style="display:flex; gap:10px; align-items:center;">
                                    <input type="hidden" name="post_id" value="<%= postId %>">
                                    <input type="hidden" name="parent_comment_id" value="<%= cid %>">
                                    <input type="text" name="content" placeholder="<%= cWriter %>님에게 답글 달기" required style="flex:1; padding:8px 12px; border-radius:18px; border:1px solid #cfd9de; font-size:14px;">
                                    <button type="submit" class="btn-primary btn-xs">답글 게시</button>
                                </form>
                            </div>
                        </div>
                    </div>
                    
                    <% 
                    List<Map<String, Object>> replies = (List<Map<String, Object>>) c.get("replies");
                    if (replies != null && !replies.isEmpty()) { %>
                        <div class="reply-wrapper">
                            <% for(Map<String, Object> r : replies) { 
                                String rWriter = (String) r.get("writer"); String rContent = (String) r.get("content");
                                String rDate = (String) r.get("date");
                            %>
                            <div class="reply-item">
                                <a href="profile.jsp?user=<%= rWriter %>" class="avatar-sm-link"><div class="avatar-sm" style="width:28px; height:28px; font-size:12px;"><%= rWriter.substring(0,1).toUpperCase() %></div></a>
                                <div style="flex:1;">
                                    <div class="post-username-row" style="font-size:13px;">
                                        <a href="profile.jsp?user=<%= rWriter %>" class="username-link"><%= rWriter %></a>
                                        <span style="color:#536471; font-weight:400; margin-left:4px;">· <%= rDate %></span>
                                    </div>
                                    <div style="margin-top:2px; font-size:14px;"><%= rContent %></div>
                                </div>
                            </div>
                            <% } %>
                        </div>
                    <% } %>
                    <% } %>
                </div>
            <% } %>
        </div>

        <div class="column-right">
            <div class="card"><h3 class="section-title">관련 트렌드</h3><div class="helper-text">현재 보고 계신 게시글과 관련된 주제입니다.</div></div>
        </div>

    </div>
</div>
</body>
</html>
<%
    if (con != null) { try { con.close(); } catch (Exception ignore) {} }
%>
<script>
    function toggleReplyForm(commentId) {
        var formDiv = document.getElementById('reply-form-' + commentId);
        document.querySelectorAll('[id^="reply-form-"]').forEach(function(el) {
            if (el.id !== formDiv.id) {
                el.style.display = 'none';
            }
        });
        formDiv.style.display = formDiv.style.display === 'none' ? 'block' : 'none';
        
        // 입력창이 열릴 때 포커스 이동 (UX 개선)
        if (formDiv.style.display === 'block') {
            formDiv.querySelector('input[name="content"]').focus();
        }
    }
</script>