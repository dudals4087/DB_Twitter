<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ include file="dbconn.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");

    // 세션에서 로그인 정보 읽기
    String currentUser = (String) session.getAttribute("currentUser");
    Boolean currentPaid = (Boolean) session.getAttribute("currentUserPaid");
    if (currentPaid == null) currentPaid = false;

    String initials = "G";
    if (currentUser != null && currentUser.length() > 0) {
        initials = currentUser.substring(0, 1).toUpperCase();
    }

    String loginMsg = null;
    String errorMsg = null;

    // 로그인 폼 전송 처리
    if ("POST".equalsIgnoreCase(request.getMethod())) {
        String uid = request.getParameter("user_id");
        String pwd = request.getParameter("pwd");

        if (uid == null || uid.trim().isEmpty() ||
            pwd == null || pwd.trim().isEmpty()) {

            loginMsg = "아이디와 비밀번호를 모두 입력해 주세요";
        } else {
            uid = uid.trim();
            pwd = pwd.trim();

            try {
                String sql = "SELECT user_id, paid FROM users WHERE user_id = ? AND pwd = ?";
                try (PreparedStatement ps = con.prepareStatement(sql)) {
                    ps.setString(1, uid);
                    ps.setString(2, pwd);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next()) {
                            String foundId = rs.getString("user_id");
                            String paidFlag = rs.getString("paid");

                            session.setAttribute("currentUser", foundId);
                            session.setAttribute("currentUserPaid", "T".equals(paidFlag));

                            if (con != null) {
                                try { con.close(); } catch (Exception ignore) {}
                            }
                            response.sendRedirect("main.jsp");
                            return;
                        } else {
                            loginMsg = "아이디 또는 비밀번호가 올바르지 않습니다";
                        }
                    }
                }
            } catch (Exception e) {
                e.printStackTrace();
                errorMsg = "로그인 처리 중 오류가 발생했어요";
            }
        }
    }
%>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>로그인  TWITTER_DB4</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
<div class="app-shell">

    <!-- 상단 헤더 -->
    <header class="app-header">
        <div class="app-header-left">
            <a href="main.jsp" class="app-logo">TWITTER_DB4</a>
            <div class="app-logo-sub">로그인</div>
        </div>
        <div class="app-header-right">
            <%
                if (currentUser == null) {
            %>
                <a href="login.jsp" class="icon-btn" title="로그인">👤</a>
                <a href="login.jsp" class="icon-btn" title="설정은 로그인 후 이용 가능">⚙</a>
                <a href="login.jsp" class="icon-btn" title="메시지는 로그인 후 이용 가능">💬</a>
            <%
                } else {
            %>
                <a href="profile.jsp" class="icon-btn" title="내 프로필"><%= initials %></a>
                <a href="settings.jsp" class="icon-btn" title="설정">⚙</a>
                <a href="messages.jsp" class="icon-btn" title="메시지">💬</a>
            <%
                }
            %>
        </div>
    </header>

    <!-- 로그인 카드 -->
    <div class="center-layout">
        <div class="auth-card">
            <div class="auth-title">TWITTER_DB4 로그인</div>
            <div class="auth-sub">
                등록된 아이디와 비밀번호를 입력해 주세요
            </div>

            <form method="post" action="login.jsp">
                <div class="form-field">
                    <div class="form-label">아이디</div>
                    <input type="text" name="user_id" class="input-text" placeholder="아이디를 입력하세요">
                </div>
                <div class="form-field">
                    <div class="form-label">비밀번호</div>
                    <input type="password" name="pwd" class="input-text" placeholder="비밀번호를 입력하세요">
                </div>
                <button type="submit" class="btn-primary" style="width:100%">로그인</button>
            </form>

            <a href="signup.jsp" class="btn-secondary" style="width:100%; display:inline-block; text-align:center; margin-top:8px;">
                새 계정 만들기
            </a>

            <%
                if (loginMsg != null) {
            %>
                <div class="msg msg-err"><%= loginMsg %></div>
            <%
                }
                if (errorMsg != null) {
            %>
                <div class="msg msg-err"><%= errorMsg %></div>
            <%
                }
            %>

            <div class="helper-text">
                로그인 후 메인 상단의 아이콘으로  
                프로필, 설정, 메시지 화면에 바로 이동할 수 있어요
            </div>
        </div>
    </div>

</div>
</body>
</html>
<%
    if (con != null) {
        try { con.close(); } catch (Exception ignore) {}
    }
%>
