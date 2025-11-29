<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ include file="dbconn.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");

    // [기존 로직 유지] 세션 및 로그인 처리
    String currentUser = (String) session.getAttribute("currentUser");
    Boolean currentPaid = (Boolean) session.getAttribute("currentUserPaid");
    if (currentPaid == null) currentPaid = false;

    String loginMsg = null;
    String errorMsg = null;

    // 로그인 폼 전송 처리
    if ("POST".equalsIgnoreCase(request.getMethod())) {
        String uid = request.getParameter("user_id"); // input name과 일치해야 함
        String pwd = request.getParameter("pwd");     // input name과 일치해야 함

        if (uid == null || uid.trim().isEmpty() ||
            pwd == null || pwd.trim().isEmpty()) {

            loginMsg = "아이디와 비밀번호를 입력해주세요.";
        } else {
            uid = uid.trim();
            pwd = pwd.trim();

            try {
                // DB에서 사용자 확인
                String sql = "SELECT user_id, paid FROM users WHERE user_id = ? AND pwd = ?";
                try (PreparedStatement ps = con.prepareStatement(sql)) {
                    ps.setString(1, uid);
                    ps.setString(2, pwd);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next()) {
                            // 로그인 성공
                            String foundId = rs.getString("user_id");
                            String paidFlag = rs.getString("paid");

                            session.setAttribute("currentUser", foundId);
                            session.setAttribute("currentUserPaid", "T".equals(paidFlag));

                            if (con != null) {
                                try { con.close(); } catch (Exception ignore) {}
                            }
                            // 메인 페이지로 이동
                            response.sendRedirect("main.jsp");
                            return;
                        } else {
                            loginMsg = "아이디 또는 비밀번호가 올바르지 않습니다.";
                        }
                    }
                }
            } catch (Exception e) {
                e.printStackTrace();
                errorMsg = "로그인 처리 중 오류가 발생했습니다.";
            }
        }
    }
%>
<!DOCTYPE html>
<html>
<head>
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@800&display=swap" rel="stylesheet">
    <meta charset="UTF-8">
    <title>로그인 / Twitter</title>
    <link rel="stylesheet" href="style.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
</head>
<body class="login-body">

    <div class="login-container">
        <div class="login-left">
            <i class="fa-brands fa-twitter big-logo"></i>
        </div>

        <div class="login-right">
            <div class="login-content">
                <h1 class="heading-1">지금 일어나고<br>있는 일</h1>
                <h2 class="heading-2">지금 가입하세요.</h2>

                <form method="post" action="login.jsp" class="login-form">
                    
                    <div class="input-group">
                        <input type="text" name="user_id" class="login-input" placeholder="휴대폰 번호, 이메일 주소 또는 사용자 아이디" required>
                    </div>
                    
                    <div class="input-group">
                        <input type="password" name="pwd" class="login-input" placeholder="비밀번호" required>
                    </div>

                    <button type="submit" class="btn-login-submit">로그인</button>
                    
                    <% if (loginMsg != null) { %>
                        <div style="color: #f4212e; font-size: 13px; margin-top: 10px; text-align: center;">
                            <%= loginMsg %>
                        </div>
                    <% } %>
                    <% if (errorMsg != null) { %>
                        <div style="color: #f4212e; font-size: 13px; margin-top: 10px; text-align: center;">
                            <%= errorMsg %>
                        </div>
                    <% } %>

                </form>

                <div class="divider">
                    <span>또는</span>
                </div>

                <div class="signup-prompt">
                    <p>계정이 없으신가요?</p>
                    <a href="signup.jsp" class="btn-signup-outline">계정 만들기</a>
                </div>
            </div>
        </div>
    </div>

    <footer class="login-footer">
        <span>소개</span>
        <span>고객센터</span>
        <span>이용약관</span>
        <span>개인정보 처리방침</span>
        <span>© 2025 Twitter Clone Project</span>
    </footer>

</body>
</html>
<%
    // DB 연결 해제 (안전장치)
    if (con != null) {
        try { con.close(); } catch (Exception ignore) {}
    }
%>